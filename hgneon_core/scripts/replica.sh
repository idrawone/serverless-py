#!/bin/bash
set -eux

PG_VERSION=${PG_VERSION:-14}

SPEC_FILE_ORG=/neonspec/hot-sb-spec.json
SPEC_FILE=/tmp/hot-sb-spec.json

echo "TENANTID=$TENANTID TIMELINEID=$TIMELINEID NODEID=$NODEID"

if [ ! -z $TENANTID ] && [ ! -z $TIMELINEID ] && [ ! -z $NODEID ]; then
	echo "Start a hot standby for compute node $NODEID on given tenant_id=$TENANTID and timeline_id=$TIMELINEID"
	sed "s/TENANT_ID/${TENANTID}/" ${SPEC_FILE_ORG} > ${SPEC_FILE}
	sed -i "s/TIMELINE_ID/${TIMELINEID}/" ${SPEC_FILE}
	sed -i "s/NODEID/${NODEID}/" ${SPEC_FILE}
	
	cat ${SPEC_FILE}
        /usr/local/bin/compute_ctl --pgdata /var/db/postgres/compute \
                -C "postgresql://cloud_admin@localhost:${PGPORT}/postgres"  \
                -b /usr/local/bin/postgres                              \
                -S ${SPEC_FILE}
else
	echo "tenantid or timeline id not specified! Cannot start replica."
fi
