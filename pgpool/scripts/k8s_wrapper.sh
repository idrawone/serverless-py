#!/bin/bash

option=$1

if [ x$option == x"start-compute" ]; then
	computeid=$2
	#computeport=$3
	if [ -z $computeid ]; then
                computeid=$COMPUTE_ID
        fi

	if [ -z $computeid ]; then
                echo "usage ./k8s_wrapper.sh start-compute [computeid]"
                echo "or set COMPUTE_ID env variable"
                exit 1
        fi

	kubectl get pods | grep "compute-pod-$computeid"
	if [ $? -eq 0 ]; then
		echo "computeid $computeid is already running"
                exit 0
	fi
	tenantid=$TENANTID
	timeline=$TIMELINEID
	if [ -z $tenantid ] || [ -z $timeline ]; then
		tenantid=$(echo $computeid | md5sum | sed 's/[- ]//g')   ## derive tenantid
		timeline=$(echo $computeid-1 | md5sum | sed 's/[- ]//g') ## derive timeline
	fi
	echo "computeid $computeid has associated tenantid=$tenantid and initial timelineid=$timeline"

	sed "s/COMPUTEID/${computeid}/" /pgpool-compute-manifest/neonpod.yml.template > /tmp/neonpod-$computeid.yml
	sed -i "s/MYTENANTID/${tenantid}/" /tmp/neonpod-$computeid.yml
	sed -i "s/MYTIMELINEID/${timeline}/" /tmp/neonpod-$computeid.yml

	kubectl apply -f /tmp/neonpod-$computeid.yml
	sleep 3

	# wait for compute to be ready to accept connections
	while [[ ! `kubectl logs compute-pod-$computeid | grep "database system is ready to accept connections"` ]]; do
		sleep 2
	done
	sleep 1
	echo "compute pod for endpoint $computeid successfully started"
elif [ x$option == x"stop-compute" ]; then
	computeid=$2

	if [ -z $computeid ]; then
		echo "usage ./k8s_wrapper.sh stop-compute [computeid] [replicaid]"
		echo "or set COMPUTE_ID env variable"
		exit 1
	fi

	kubectl delete pod compute-pod-$computeid

elif [ x$option == x"start-replica" ]; then
	computeid=$2
	repid=$3
	if [ -z $computeid ] || [ -z $repid ]; then
		echo "usage ./k8s_wrapper.sh start-replica [computeid] [replicaid]"
		echo "or set COMPUTE_ID env variable"
		exit 1
	fi

	tenantid=$TENANTID
	timeline=$TIMELINEID

	numcomp=$(kubectl get pods | grep $computeid | grep -v 'pgpool' | wc -l)

	if [ $numcomp -ge 9 ]; then
		echo "Max number of replicas reached!"
		exit 1
	fi

	sed "s/COMPUTEID/${computeid}/" /pgpool-compute-manifest/replicapod.yml.template > /tmp/replicapod-$computeid-$repid.yml
	sed -i "s/MYTENANTID/${tenantid}/" /tmp/replicapod-$computeid-$repid.yml
	sed -i "s/MYTIMELINEID/${timeline}/" /tmp/replicapod-$computeid-$repid.yml
	sed -i "s/REPLICAID/${repid}/" /tmp/replicapod-$computeid-$repid.yml

	kubectl apply -f /tmp/replicapod-$computeid-$repid.yml
	sleep 3

	# wait for replica to be ready to accept connections
	while [[ ! `kubectl logs replica-pod-$computeid-$repid | grep "database system is ready to accept read-only connections"` ]]; do
		sleep 2
	done
	
	sleep 1
	echo "replica pod for endpoint $computeid-$repid successfully started"

	/opt/pgpool-II/bin/pgpool -f /opt/pgpool-II/etc/pgpool.conf reload
	/opt/pgpool-II/bin/pcp_attach_node -w -h localhost -U postgres -p 9899 -n $repid

elif [ x$option == x"stop-replica" ]; then
	computeid=$2
	repid=$3
	if [ -z $computeid ] || [ -z $repid ]; then
		echo "usage ./k8s_wrapper.sh stop-replica [computeid] [replicaid]"
		echo "or set COMPUTE_ID env variable"
		exit 1
	fi

	tenantid=$TENANTID
	timeline=$TIMELINEID
	numcomp=$(kubectl get pods | grep $computeid | grep -v pgpool | wc -l)

	/opt/pgpool-II/bin/pgpool -f /opt/pgpool-II/etc/pgpool.conf reload
	/opt/pgpool-II/bin/pcp_detach_node -w -h localhost -U postgres -p 9899 -n $repid
	
	kubectl delete pod replica-pod-$computeid-$repid

elif [ x$option == x"create-pcppass" ]; then
	echo "creating .pcppass..."
	echo -n "localhost:9899:postgres:postgres" > $PCPPASSFILE
	chmod 600 $PCPPASSFILE

elif [ x$option == x"append-conf" ]; then
	computeid=$2
	echo "
backend_hostname1 = 'replica-pgpool-service-$computeid-1'
backend_port1 = 55433
backend_weight1 = 0.3
backend_flag1 = 'ALLOW_TO_FAILOVER'

backend_hostname2 = 'replica-pgpool-service-$computeid-2'
backend_port2 = 55433
backend_weight2 = 0.3
backend_flag2 = 'ALLOW_TO_FAILOVER'

backend_hostname3 = 'replica-pgpool-service-$computeid-3'
backend_port3 = 55433
backend_weight3 = 0.3
backend_flag3 = 'ALLOW_TO_FAILOVER'

backend_hostname4 = 'replica-pgpool-service-$computeid-4'
backend_port4 = 55433
backend_weight4 = 0.3
backend_flag4 = 'ALLOW_TO_FAILOVER'

backend_hostname5 = 'replica-pgpool-service-$computeid-5'
backend_port5 = 55433
backend_weight5 = 0.3
backend_flag5 = 'ALLOW_TO_FAILOVER'

backend_hostname6 = 'replica-pgpool-service-$computeid-6'
backend_port6 = 55433
backend_weight6 = 0.3
backend_flag6 = 'ALLOW_TO_FAILOVER'

backend_hostname7 = 'replica-pgpool-service-$computeid-7'
backend_port7 = 55433
backend_weight7 = 0.3
backend_flag7 = 'ALLOW_TO_FAILOVER'

backend_hostname8 = 'replica-pgpool-service-$computeid-8'
backend_port8 = 55433
backend_weight8 = 0.3
backend_flag8 = 'ALLOW_TO_FAILOVER'" >> /opt/pgpool-II/etc/pgpool.conf
	/opt/pgpool-II/bin/pgpool -f /opt/pgpool-II/etc/pgpool.conf reload

elif [ x$option == x"start-endpoint" ]; then
        endpoint=$2

        if [ -z $endpoint ]; then
                endpoint=$ENDPOINT_ID
        fi

        if [ -z $endpoint ]; then
                echo "usage ./k8s_wrapper.sh start-endpoint [endpoint id]"
                echo "or set ENDPOINT_ID env variable"
                exit 1
        fi

        kubectl get pods | grep "pgpool-$endpoint"
        if [ $? -eq 0 ]; then
                echo "endpoint $endpoint is already running"
                exit 0
        fi

        res=$(curl --request GET "http://handler-service:8989/endpoint" \
              --header 'Content-Type: application/json' \
              --data '{}')
        tenantid=$(echo ${res} | jq ".[] | select(.name == \"$endpoint\") | .tenant" | sed 's/^"\(.*\)"$/\1/')
        timelineid=$(echo ${res} | jq ".[] | select(.name == \"$endpoint\") | .timeline" | sed 's/^"\(.*\)"$/\1/')

        if [ -z $tenantid ] || [ -z $timelineid ]; then
                echo "failed to retrieve tenantid and timeline id of endpoint $endpoint"
               exit 1
        fi
        echo "endpoint: $endpoint has corresponding tenantid $tenantid and timelineid $timelineid"
        sed "s/COMPUTEID/${endpoint}/" /endpoint/pgpool-configmap.yml.template > /tmp/pgpool-configmap-$endpoint.yml
        sed "s/COMPUTEID/${endpoint}/" /endpoint/pgpool-deploy.yml.template > /tmp/pgpool-deploy-$endpoint.yml

        sed -i "s/MYTENANTID/${tenantid}/" /tmp/pgpool-deploy-$endpoint.yml
        sed -i "s/MYTIMELINEID/${timelineid}/" /tmp/pgpool-deploy-$endpoint.yml

        kubectl apply -f /tmp/pgpool-configmap-$endpoint.yml
        kubectl apply -f /tmp/pgpool-deploy-$endpoint.yml
	
	# wait for endpoint to be ready to accept connections
	sleep 3
	pod=$(kubectl get pod | grep "pgpool-$endpoint" | awk '{print $1}')
	echo "endpoint pod name $pod"
        while [[ ! `kubectl logs $pod | grep "pgpool-II successfully started"` ]]; do
                sleep 2
        done
	sleep 1
	echo "endpoint pod name $pod successfully started"

else
	echo "unsupported option $option. Supported options are: "
        echo -e "\tstart-compute"
		echo -e "\tstop-compute"
		echo -e "\tstart-replica"
		echo -e "\tstop-replica"
		echo -e "\tcreate-pcppass"
	exit 1
fi

exit 0
