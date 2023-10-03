#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "usage ./hgneonstorage.sh [service]"
fi

service=$1
echo $service

if [ x$service == x"broker" ]; then
	echo "starting broker"
	storage_broker --listen-addr=0.0.0.0:50051
elif [ x$service == x"pageserver" ]; then
	echo "starting pageserver"
	pageserver -D /data/.neon/ \
      		-c "broker_endpoint='$BROKER_ENDPOINT'" \
      		-c "listen_pg_addr='0.0.0.0:6400'" \
      		-c "listen_http_addr='0.0.0.0:9898'" \
		-c "remote_storage={endpoint='http://minio-store:9000', bucket_name='neon', bucket_region='eu-north-1', prefix_in_bucket='/pageserver/'}"

elif [ x$service == x"safekeeper" ]; then\
	echo "starting safekeeper id $SAFEKEEPER_ID"
	safekeeper \
      		--listen-pg=$SAFEKEEPER_ADVERTISE_URL \
      		--listen-http=$LISTEN_HTTP \
      		--id=$SAFEKEEPER_ID \
      		--broker-endpoint=$BROKER_ENDPOINT \
		--availability-zone=sk-$SAFEKEEPER_ID
      		-D /data \
		--remote-storage="{endpoint='http://minio-store:9000',bucket_name='neon',bucket_region='eu-north-1',prefix_in_bucket='/safekeeper/'}"
fi

