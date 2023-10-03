#!/bin/bash

option=$1
pgpoolconf="/opt/pgpool-II/etc/pgpool.conf"

ENDPOINT_PREFIX="pgpool-service"
ENDPOINT_PORT=9999
ENDPOINT_WEIGHT=1
ENDPOINT_FLAG_ADD="ALWAYS_PRIMARY"
ENDPOINT_FLAG_DEL="ALWAYS_PRIMARY|DELETED"

# create .pcppass file if not exist
if [ ! -f $PCPPASSFILE ]; then
	echo "creating .pcppass..."
	echo "127.0.0.1:9899:postgres:postgres" > $PCPPASSFILE
	chmod 600 $PCPPASSFILE
fi

function addnode()
{
        backend_hostname=$1
        backend_hostport=$2
        backend_weight=$3
        backend_flag=$4
        maxnode=0
	atleastone=0

	echo "adding node: $backend_hostname | $backend_hostport | $backend_weight | $backend_flag"

	entry=$(grep -w $backend_hostname $pgpoolconf | grep "backend_hostname")
	if [ $? -eq 0 ]; then
		echo "node $backend_hostname already exists"
		### todo: find its index number and remove DELETED flag
                line=$(echo $entry | cut -d "=" -f 1)
                number=${line#"backend_hostname"}
		sed -i "/^backend_flag$number/ c\\backend_flag$number= '$backend_flag'" $pgpoolconf
		exit 0
	fi

        grep backend_hostname $pgpoolconf > /tmp/poolnode.tmp
        while read line;
        do
                if [[ $line == \#* ]]; then
                        continue
                fi
                line=$(echo $line | cut -d "=" -f 1)
                number=${line#"backend_hostname"}

                if [ $number -gt $maxnode ]; then
                        maxnode=$number
                fi
		atleastone=1
        done < /tmp/poolnode.tmp

        echo "maxnode = $maxnode"
	if [ $atleastone -eq 1 ]; then
        	next_backend_id=$((maxnode + 1))
	else
		next_backend_id=0
	fi
        echo "next_backend_id $next_backend_id"
        rm /tmp/poolnode.tmp

        # append to pgpool.conf
        if [ -z $backend_hostname ] || [ -z $backend_hostport ] || \
                [ -z $backend_weight ] || [ -z $backend_flag ]; then
                echo "usage: addnode [hostname] [hostport] [weight] [flag]"
                exit 1
        else
                echo "" >> $pgpoolconf
                echo "backend_hostname$next_backend_id = '$backend_hostname'" >> $pgpoolconf
                echo "backend_port$next_backend_id = $backend_hostport" >> $pgpoolconf
                echo "backend_weight$next_backend_id = $backend_weight" >> $pgpoolconf
                echo "backend_flag$next_backend_id = '$backend_flag'" >> $pgpoolconf
        fi

        # reload pgpool
        /opt/pgpool-II/bin/pcp_reload_config -p 9899 -h 127.0.0.1 -w
}

function deletenode()
{
        backend_hostname=$1
        backend_flag=$2
	
	echo "deleting node: $backend_hostname | $backend_flag"
	record=$(grep $1 $pgpoolconf)
	if [ $? -eq 0 ]; then
		#record exist
		echo "backend hostname record found: $record"
		line=$(echo $record | cut -d "=" -f 1)
		number=${line#"backend_hostname"}
		echo "$backend_hostname has index value of $number"

		grep backend_flag$number $pgpoolconf | grep -v "#backend_flag" | grep 'DELETED' > /dev/null
		if [ $? -eq 0 ]; then
			echo "backend_flag$number is already set to DELETED"
			exit 0
		fi

	else
		#record not exist
		echo "backend hostname $backend_hostname not found"
		exit 1
	fi

	sed -i "/^backend_flag$number/ c\\backend_flag$number= '$backend_flag'" $pgpoolconf
        
	# reload pgpool
        /opt/pgpool-II/bin/pcp_reload_config -p 9899 -h 127.0.0.1 -w
}


if [ x$option == x"addnode" ]; then
	endpoint=$2
	
	if [ -z $endpoint ]; then
		echo "usage: ./poolnodes.sh addnode [endpoint]"
		exit 1
	fi
	
	addnode "$ENDPOINT_PREFIX-$endpoint" $ENDPOINT_PORT $ENDPOINT_WEIGHT "$ENDPOINT_FLAG_ADD"
	
elif [ x$option == x"deletenode" ]; then
	endpoint=$2

        if [ -z $endpoint ]; then
                echo "usage: ./poolnodes.sh deletenode [endpoint]"
                exit 1
        fi

        deletenode "$ENDPOINT_PREFIX-$endpoint" "$ENDPOINT_FLAG_DEL"
else
	echo "unsupported option $option. Supported options are: "
        echo -e "\taddnode"
        echo -e "\tdeletenode"
	exit 1
fi
exit 0
