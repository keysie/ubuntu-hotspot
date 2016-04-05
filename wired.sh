#!/bin/bash

# Script to automatically shut down network-manager
# and prepare the wired ethernet-connection for use
# as base for the wlan-routing. 
#
# Adjust wired.config for your current network
# topology.

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
ok="[${green}ok${reset}]"
error="[${red}error${reset}]"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IPREGEX='\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}'
MACREGEX='\([0-9a-fA-F]\{2\}:\)\{5\}[0-9a-fA-F]\{2\}'




# evaluate command result (exit code)
eval_exit()
{
	if [ "${1}" == "0" ]
	then
		echo "${ok}"
	else
		echo "${error}"
		echo "${result}"

		if [ "${2}" != "noexit" ]; then
			exit 1
		fi
	fi
}

# Check parsed MAC address
check_parse_mac() #name value
{
	echo ${2} | grep -q "^${MACREGEX}$"

	if [ $? -ne 0 ]
	then
		echo "{error}"
		echo "Unknown value for ${1}: ${2}"
		echo "Expected value: valid MAC address of form XX:XX:XX:XX:XX:XX"
		exit 1
	fi
}

# Check parsed IP address
check_parse_ip() #name value
{

	echo ${2} | grep -q "^${IPREGEX}$"

	if [ $? -ne 0 ]
	then
		echo "{error}"
		echo "Unknown value for ${1}: ${2}"
		echo "Expected value: valid IPv4 address."
		exit 1
	fi
}

# check parsed ip prefix
check_parse_prefix() #name value
{
	if [ ${2} -lt 0 ] || [ ${2} -gt 32 ]; then
	 	echo "{error}"
		echo "Unknown value for ${1}: ${2}"
		echo "Expected value: valid IPv4 prefix (0...32)."
		exit 1
	fi
}

# get original hardware mac address
get_hw_mac()
{
	ORIMAC="$(ethtool -P eth0 | grep -o "${MACREGEX}")"
}


# Parse wired.conf
parse_config()
{
	echo -n "Parsing wired.conf... "
	IFS="="
	while read -r name value
	do
		# ignore commented or empty lines
		echo "${name}" | grep -q '\(^[#]\)\|\(^[[:space:]]*$\)'
		if [ $? -eq 0 ]
		then
			continue
		fi

		#echo "Content of $name is ${value}"

		case ${name} in
		"change-mac")
			if [ "${value}" == "yes" ] || [ "${value}" == "no" ]
			then
				MACCHANGE="${value}"
			else
				echo "{error}"
				echo "Unknown value for ${name}: ${value}"
				echo 'Expected value: "yes" or "no"'
				exit 1
			fi
			;;
		"fake-mac")
			if [ "${MACCHANGE}" == "yes" ]
			then
				check_parse_mac "${name}" "${value}"
				FAKEMAC="${value}"
			fi
			;;
		"type")
			if [ "${value}" == "dhcp" ] || [ "${value}" == "fix" ]
			then
				NETTYPE="${value}"
			else
				echo "{error}"
				echo "Unknown value for ${name}: ${value}"
				echo 'Expected value: "yes" or "no"'
				exit 1
			fi
			;;
		"ip")
			if [ "${NETTYPE}" == "fix" ]
			then
				IFS='/' read IP PREFIX <<< ${value}
				check_parse_ip "${name}" "${IP}"
				check_parse_prefix "prefix" "${PREFIX}"
			fi
			;;
		"gateway")
			if [ "${NETTYPE}" == "fix" ]
			then
				check_parse_ip "${name}" "${value}"
				GATEWAY="${value}"
			fi
			;;
		"dns")
			if [ "${NETTYPE}" == "fix" ]
			then
				check_parse_ip "${name}" "${value}"
				DNS="${value}"
			fi
			;;
		"broadcast")
			if [ "${NETTYPE}" == "fix" ]
			then
				check_parse_ip "${name}" "${value}"
				BROADCAST="${value}"
			fi
			;;
		esac
	done < ${DIR}/wired.conf

	echo "${ok}"
}

# Start network-manager
start_nm()
{
	echo -n "Starting network manager... "
	result="$(start network-manager 2>&1)"
	case ${result} in
	"start: Job is already running: network-manager")
		echo "[${green}already running${reset}]"
		;;
	"network-manager start/running, process "[0-9]*)
		pid="$(echo ${result} | grep -P -o '(?<=(start/running, process ))[0-9]*(?=())')"
		echo "[${green}pid=${pid}${reset}]"
		;;
	*)
		echo "${error}"
		echo "${result}"
		exit 1
	esac
}


# Stop network-manager
stop_nm()
{
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
			exit 1
		fi
	fi
}


# release dhcp lease (if any) and bring eth0 down
if_down()
{
	if [ "${NETTYPE}" == "dhcp" ]; then
		echo -n "Stopping dhclient on eth0... "
		dhclient -r eth0
		eval_exit $? "noexit"
	fi

	echo -n "Removing routes via eth0... "
	ip route flush dev eth0
	eval_exit $? "noexit"

	echo -n "Removing eth0 ip's ... "
	ip addr flush dev eth0
	eval_exit $? "noexit"

	echo -n "Bringing eth0 down... "
	ip link set eth0 down
	eval_exit ${?} "noexit"

	# macchange
	if [ "${MACCHANGE}" == "yes" ]
	then
		echo -n "Resetting MAC address... "
		get_hw_mac
		ip link set dev eth0 address "${ORIMAC}"
		CURRENTMAC="$(ip link show dev eth0 | grep -P -o '(?<=(link/ether )).*(?=( brd ))')"
		if [ "${CURRENTMAC,,}" == "${ORIMAC,,}" ]
		then
			echo "[${green}${CURRENTMAC}${reset}]"
		else
			echo "${error}"
			exit 1
		fi
	fi

}


# bring eth0 up
if_up()
{
	# macchange
	if [ "${MACCHANGE}" == "yes" ]
	then
		echo -n "Changing MAC address... "
		ip link set dev eth0 down
		ip link set dev eth0 address "${FAKEMAC}"
		CURRENTMAC="$(ip link show dev eth0 | grep -P -o '(?<=(link/ether )).*(?=( brd ))')"
		if [ "${CURRENTMAC,,}" == "${FAKEMAC,,}" ]
		then
			echo "[${green}${CURRENTMAC}${reset}]"
		else
			echo "${error}"
			exit 1
		fi
	fi

	# configuration "dhcp"
	if [ "${NETTYPE}" == "dhcp" ]
	then
		echo -n "Bringing eth0 up... "
		ip link set dev eth0 up
		eval_exit $?
		
		echo -n "Starting dhcp client... "
		timeout 'dhclient -q eth0' 7

		case $? in
		"0")
			echo "${ok}"
			;;
		"124")
			echo "[${red}timed out${reset}]"
			exit 1
			;;
		esac
	fi

	# configuration "fix"
	if [ "${NETTYPE}" == "fix" ]
	then
		echo -n "Configuring eth0... "
		ip addr flush dev eth0
		ip addr add "${IP}/${PREFIX}" broadcast "${BROADCAST}" dev eth0
		eval_exit $?

		echo -n "Bringing eth0 up... "
		ip link set dev eth0 up
		eval_exit $?
		
		echo -n "Setting up default gateway... "
		ip route add default via "${GATEWAY}"
		eval_exit $?

		echo -n "Adding DNS server to resolv.conf... "
		echo "nameserver ${DNS}" >> /etc/resolv.conf
		eval_exit $?
	fi
}

# Make sure eth0 is up and running by
# sending 4 packets and checking if they re-
# turn.
connection_test()
{
	echo -n "Test-ping to www.google.com... "
	result="$(timeout 5 ping -I eth0 -i 0.5 -c 4 -n -q www.google.com 2>&1 | grep -P -o '(?<=(4 packets transmitted, ))[0-9](?=( received, ))')"
	case ${result} in
		"4")
			echo "${ok}"
			;;
		"3" | "2" | "1")
			echo "${error}"
			echo "4 packets sent; only ${result} received!"
			exit 1
			;;
		"")
			result="0"
			echo "${error}"
			echo "4 packets sent; only ${result} received!"
			exit 1
			;;
		*)
			echo "${error}"
			exit 1
	esac
}


# Make sure script is run as root or sudo
root_check()
{
	if [ "$(whoami)" != "root" ]
	then
		echo 
		echo "Error! Must run as root!"
		echo
		exit 1
	fi
}


# Check validity of input argument
arg_check()
{
	if [ "$#" -gt 1 ]; then
		echo
		echo "Too many arguments!"
		echo "Usage: $0 [start|stop]"
		echo
		exit 1
	fi

	if [ "$#" -lt 1 ]; then
		echo
		echo "Too few arguments!"
		echo "Usage: $0 [start|stop]"
		echo
		exit 1
	fi

	if [ "$1" != "start" ] && [ "$1" != "stop" ]; then
		echo
		echo "Unknown arguments encountered!"
		echo "Usage: $0 [start|stop]"
		echo
		exit 1
	fi
}


# ---------- Script starting point --------------

root_check
arg_check $*

echo
echo "=========== WIRED-SETUP ============"
echo

parse_config

case "$1" in
	"start")
		stop_nm
		if_up
		connection_test
		exit 0
		;;
	"stop")
		if_down
		start_nm
		exit 0
		;;
	*)
		exit 1
		;;
esac



