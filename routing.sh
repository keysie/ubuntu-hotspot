#!/bin/bash

######################################################################
#
# ubuntu-hotspot: make your ubuntu laptop a wlan hotspot
# Copyright (C) 2016  Robert Simpson
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Contact me by mail via robert_zwilling@web.de or follow my github
# account github.com/keysie
#
#######################################################################



# This script enables the forwarding of networking packages through
# the computer, effectivly turning it into a (wireless) router.


# Configure everything here:

EXTIF="eth0"	# WAN side
INTIF="wlan0"	# LAN side
MASK="192.168.10.0/24"	# Netmask


# Some variables used (do not change):

ME=$(basename "$0")
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
ok="[${green}ok${reset}]"
error="[${red}error${reset}]"


# Method definitions
#   Result evaluation
evaluate() 
{
	if [ "${#@}" -eq 0 ]
	then
		echo "${ok}"
	else
		echo "${error}"
		echo "${result}"
		exit
	fi
}

#   Reset ip_tables
ipt_reset()
{
	result="$(iptables -F 2>&1)"
	result=${result}"$(iptables -X 2>&1)"
	result=${result}"$(iptables -t nat -F 2>&1)"
	echo "${result}"
}

# Apply new ip_table rules
ipt_setrules()
{
	result="$(iptables -A FORWARD -o $EXTIF -i $INTIF -s $MASK -m conntrack --ctstate NEW -j ACCEPT 2>&1)"
	result=${result}"$(iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>&1)"
	result=${result}"$(iptables -t nat -A POSTROUTING -o $EXTIF -j MASQUERADE 2>&1)"
	echo "${result}"
}

# Check kernel modules
mod_check()
{
	result="$(depmod -a 2>&1)"

	result=${result}"$(modprobe ip_tables 2>&1)"
	result=${result}"$(modprobe nf_conntrack 2>&1)"
	result=${result}"$(modprobe nf_conntrack_ftp 2>&1)"
	result=${result}"$(modprobe nf_conntrack_irc 2>&1)"
	result=${result}"$(modprobe iptable_nat 2>&1)"
	result=${result}"$(modprobe nf_nat_ftp 2>&1)"

	echo "${result}"
}

#   Enable forwarding
enable_fwd()
{
	result="$(sysctl -wq net.ipv4.ip_forward=1 2>&1)"
	echo "${result}"
}

#   Disable forwarding
disable_fwd()
{
	result="$(sysctl -wq net.ipv4.ip_forward=0 2>&1)"
	echo "${result}"
}

#   Start
start_route()
{
	echo -n "Checking kernel modules..."
	evaluate $(mod_check)

	echo -n "Resetting ip_tables..."
	evaluate $(ipt_reset)

	echo -n "Applying new ip_table rules..."
	evaluate $(ipt_setrules)

	echo -n "Enabling ip forwarding in kernel..."
	evaluate $(enable_fwd)
}

#   Stop
stop_route()
{
	echo -n "Disabling ip forwarding in kernel..."
	evaluate $(disable_fwd)

	echo -n "Resetting ip_tables..."
	evaluate $(ipt_reset)

	exit 0
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



# Main program part
root_check
arg_check $*

echo
echo "========== ROUTING-SETUP ==========="
echo

case "$1" in
	"start")
		start_route
		exit 0
		;;
	"stop")
		stop_route
		exit 0
		;;
	*)
		exit 1
		;;
esac



