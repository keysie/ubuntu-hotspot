#!/bin/bash

# Automatic WLAN-Access-Point setup script
# Copyright by Keysie, October 2015
#
# This script executes four steps prior to starting the access-
# point:
# 1) Stop the ubuntu network manager
# 2) Make sure wlan is not blocked by rfkill
# 3) Set up local IP address to 192.168.10.1
# 4) Start the dhcp server with range X.X.X.5 ... X.X.X.10
#
# The the AP will be started. It runs until Ctrl+C is pressed. 
# After this, clean up:
# 1) Stop dhcp again
#
# Each command's result is stored in a variable which is then
# evaluated to check if the command was successful or not.
 

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
ok="[${green}ok${reset}]"
error="[${red}error${reset}]"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"



# ==== result evaluation short ====
eval_short() 
{
	if [ "${#@}" -eq 0 ]
	then
		echo "${ok}"
	else
		echo "${error}"
		echo "${result}"
		exit 1
	fi
}

# ==== int trap: code to exec after Ctrl+C ====
int_trap() {
echo
echo -n "Stopping DHCP-Server... "
result="$(service isc-dhcp-server stop 2>&1)"
case ${result} in
"isc-dhcp-server stop/waiting")
	echo "${ok}"
	;;
"stop: Unknown instance: ")
	echo "[${green}already stopped${reset}]"
	;;
*)
	echo "${error}"
	echo "${result}"
esac

# Restore original dhcpd.conf
echo -n "Restoring original DHCP configuration... "
result="$(mv -f ${DIR}/dhcpd.conf.bak /etc/dhcp/dhcpd.conf 2>&1 1>/dev/null)"
eval_short ${result}

# Put wlan0 interface down
echo -n "Shutting down and blocking WLAN... "
result="$(ifconfig wlan0 down 2>&1 1>/dev/null)"
result=${result}"$(rfkill block wlan 2>&1 1>/dev/null)"
eval_short ${result}
}


# Make sure script is run as root or sudo

if [ "$(whoami)" != "root" ]
then
	echo 
	echo "Error! Must run as root!"
	echo
	exit 1
fi

# Program start

echo
echo "======== ACCESSPOINT SETUP ========="
echo
echo -n "Stopping network manager... "
result="$(stop network-manager 2>&1 1>/dev/null)"
if [ "${#result}" -eq 0 ]
then
	echo "${ok}"
else
	if [ "${result}" = "stop: Unknown instance: " ]
	then
		echo "[${green}already stopped${reset}]"
	else
		echo "${error}"
		echo "${result}"
		return 1
	fi
fi

echo -n "Unblocking wlan interface... "
result="$(rfkill unblock wlan 2>&1)"
eval_short ${result}

sleep 2

echo -n "Setting wlan ip to 192.168.10.1... "
result="$(ifconfig wlan0 192.168.10.1 2>&1)"
eval_short ${result}

# Extract DNS by sending a DNS resolution
# request for www.google.com out using dig.
echo -n "Querying DNS-Server for its IP... "
result="$(dig www.google.com +short +identify | grep -m 1 -P -o '(?<=(from server ))([0-9]{1,3}\.){3}[0-9]{1,3}(?=( in ))')"
if [ "${#result}" -ne 0 ]
then
	DNS="${result}"
	echo "[${green}${DNS}${reset}]"
else
	echo "${error}"
	echo "IP of DNS-Server could not be found!"
	exit 1
fi

# Modify local version of dhcpd.conf by
# inserting the previously extracted IP of the
# DNS server.
echo -n "Modifying local DHCP config file... "
result="$(sed -e "s/option domain-name-servers \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\};/option domain-name-servers ${DNS};/" -i ${DIR}/dhcpd.conf 2>&1 1>/dev/null)"   
eval_short ${result}

# Backup actual version of dhcpd.conf
# from /etc/dhcp/dhcpd.conf to ./dhcpd.conf.bak
echo -n "Generating backup of current DHCP config file... "
result="$(cp /etc/dhcp/dhcpd.conf ${DIR}/dhcpd.conf.bak 2>&1 1>/dev/null)"
eval_short ${result}

# Overwrite actual dhcpd.conf with
# modified version
echo -n "Applying modified DHCP configuration..."
result="$(cp -f ${DIR}/dhcpd.conf /etc/dhcp/dhcpd.conf 2>&1 1>/dev/null )"
eval_short ${result}

# Start DHCP Server
echo -n "Starting DHCP-Server... "
result="$(service isc-dhcp-server start 2>&1)"
case ${result} in
"start: Job is already running: isc-dhcp-server")
	echo "[${green}already running${reset}]"
	;;
"isc-dhcp-server start/running, process "[0-9]*)
	pid="$(echo ${result} | grep -P -o '(?<=(start/running, process ))[0-9]*(?=())')"
	echo "[${green}pid=${pid}${reset}]"
	;;
*)
	echo "${error}"
	echo "${result}"
	exit 1
esac

echo "Starting Accesspoint..."

trap int_trap EXIT # This catches Ctrl+C and executes above method

hostapd ${DIR}/hotspot.conf
