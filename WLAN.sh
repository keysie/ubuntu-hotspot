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

# Print license info
echo
echo "Ubuntu-Hotspot  Copyright (C) 2016  Robert Simpson"
echo
echo "This program comes with ABSOLUTELY NO WARRANTY."
echo "This is free software, and you are welcome to redistribute it"
echo "under certain conditions; see LICENSE for details."
echo
echo
sleep 2

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

#trap stop_ap EXIT

$DIR/wireless.sh
WIFIPID="$!"

sleep 3

stop_ap

echo
echo "All done"
echo


