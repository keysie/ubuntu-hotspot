#!/bin/bash

find_dhclient
{
	cpids=`pgrep -P $1|xargs`

	for cpid in $cpids; do
		find_dhclient $cpid
	done

	ps -p $1 | grep dhclient >/dev/null

	if [ "$?" == "0" ]; then
		echo $1
	fi
}

find_dhclient $1
