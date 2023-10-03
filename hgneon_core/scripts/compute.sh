#!/bin/bash
set -eux

PG_VERSION=${PG_VERSION:-14}

#SPEC_FILE_ORG=/var/db/postgres/specs/spec.json
SPEC_FILE_ORG=/neonspec/spec.json
SPEC_FILE=/tmp/spec.json

echo "Waiting pageserver become ready."
while ! nc -z ipc-service 6400; do
     sleep 1;
done
echo "Page server is ready."
echo "TENANTID=$TENANTID TIMELINEID=$TIMELINEID"

if [ -z $TENANTID ] && [ -z $TIMELINEID ]; then

	echo "Create a tenant and timeline"
	PARAMS=(
     		-sb 
     		-X POST
     		-H "Content-Type: application/json"
     		-d "{}"
     		http://ipc-service:9898/v1/tenant/
	)
	tenant_id=$(curl "${PARAMS[@]}" | sed 's/"//g')

	PARAMS=(
     		-sb 
     		-X POST
     		-H "Content-Type: application/json"
     		-d "{\"tenant_id\":\"${tenant_id}\", \"pg_version\": ${PG_VERSION}}"
     		"http://ipc-service:9898/v1/tenant/${tenant_id}/timeline/"
	)
	result=$(curl "${PARAMS[@]}")
	echo $result | jq .

	echo "Overwrite tenant id and timeline id in spec file"
	tenant_id=$(echo ${result} | jq -r .tenant_id)
	timeline_id=$(echo ${result} | jq -r .timeline_id)

	sed "s/TENANT_ID/${tenant_id}/" ${SPEC_FILE_ORG} > ${SPEC_FILE}
	sed -i "s/TIMELINE_ID/${timeline_id}/" ${SPEC_FILE}

	cat ${SPEC_FILE}

	echo "Start compute node"
	/usr/local/bin/compute_ctl --pgdata /var/db/postgres/compute \
     		-C "postgresql://cloud_admin@localhost:${PGPORT}/postgres"  \
     		-b /usr/local/bin/postgres                              \
     		-S ${SPEC_FILE}
elif [ -z $TENANTID ] && [ ! -z $TIMELINEID ]; then
	echo "create a new timeline on given tenant_id=$TENANTID To be done next"

else
	echo "Start compute node on given tenant_id=$TENANTID and timeline_id=$TIMELINEID"
	
	## check if tenantid exists
	res=$(curl --request GET "http://ipc-service:9898/v1/tenant/$TENANTID" \
              --header 'Content-Type: application/json' \
	      --data '{}')
	
	if [[ $res == *"NotFound"* ]]; then
		## create this tenant
		echo "creating a new tenant with tenantid=$TENANTID"
		PARAMS=(
                	-sb
               		-X POST
                	-H "Content-Type: application/json"
			-d "{\"new_tenant_id\": \"${TENANTID}\"}"
                	http://ipc-service:9898/v1/tenant/
        	)
		result=$(curl "${PARAMS[@]}" | sed 's/"//g')
	fi

	## check if timeline exists
	res=$(curl --request GET "http://ipc-service:9898/v1/tenant/$TENANTID/timeline/$TIMELINEID" \
              --header 'Content-Type: application/json' \
              --data '{}')

	if [[ $res == *"NotFound"* ]]; then
		## create this timeline
		echo "creating a new timeline $TIMELINEID under tenantid=$TENANTID"
		PARAMS=(
     			-sb 
     			-X POST
     			-H "Content-Type: application/json"
     			-d "{\"tenant_id\":\"${TENANTID}\", \"pg_version\": ${PG_VERSION}, \"new_timeline_id\":\"${TIMELINEID}\"}"
     			"http://ipc-service:9898/v1/tenant/${TENANTID}/timeline/"
		)
		result=$(curl "${PARAMS[@]}")
        	echo $result | jq .
	fi

	sed "s/TENANT_ID/${TENANTID}/" ${SPEC_FILE_ORG} > ${SPEC_FILE}
	sed -i "s/TIMELINE_ID/${TIMELINEID}/" ${SPEC_FILE}

	cat ${SPEC_FILE}
        echo "Start compute node"
        /usr/local/bin/compute_ctl --pgdata /var/db/postgres/compute \
                -C "postgresql://cloud_admin@localhost:${PGPORT}/postgres"  \
                -b /usr/local/bin/postgres                              \
                -S ${SPEC_FILE}

fi
