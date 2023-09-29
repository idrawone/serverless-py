#!/bin/bash
res=$(mc alias set minio http://minio-store:9000 minio password && mc mb minio/neon --region=eu-north-1)
if [ $? -eq 0 ]; then
	echo "default bucket successfully done"
	exit 0
else
	if [[ $res == *"successfully"* ]]; then
		echo "default bucket successfully added"
		exit 0
	else
		echo "default bucket failed to add"
		exit 1
	fi
fi
