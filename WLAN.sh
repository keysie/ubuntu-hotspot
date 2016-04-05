#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
ok="[${green}ok${reset}]"
error="[${red}error${reset}]"

stop_ap()
{
	$DIR/routing.sh stop
	$DIR/wired.sh stop
}

# Make sure script is run as root or sudo
if [ "$(whoami)" != "root" ]
then
	echo 
	echo "Error! Must run as root!"
	echo
	exit 0
fi

$DIR/wired.sh start

if [ $? -ne 0 ]; then
	$DIR/wired.sh stop
	exit 1
fi

sleep 1

$DIR/routing.sh start

if [ $? -ne 0 ]; then
	$DIR/wired.sh stop
	$DIR/routing.sh stop
	exit 1
fi

sleep 1

trap stop_ap EXIT

$DIR/wireless.sh
WIFIPID="$!"

sleep 3

stop_ap

echo
echo "All done"
echo


