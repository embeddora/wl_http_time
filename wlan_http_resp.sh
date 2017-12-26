#!/bin/bash 
#
# (C) Copyright 2018, [n/a], info@embeddora.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#

. $0.lib
#echo "names are: 0 $0 1 $1 2 $2 3 $3    4 $4 5 $5 6 $6     7 $7 8 $8 9 $9 "

FEW_SECONDS="3"
FEW_SECONDS_W="1"

TMO="600"
TIME="0"
OUTPUT=""
HTTP_PACKET_MARKER="http-eq"

TMO_W="600"
TIME_W="0"
OUTPUT_W=""
ESSID_MARKER="WIFIPASSWORD_24"

TMO_C="600"
TIME_C="0"
OUTPUT_C=""

INT="wlan0"


poll_webserver()
{
	echo "SENDING HTTP-REQUEST TO $ESSID_MARKER"

	echo "Running dhclient"

	dhclient $INT -v

	ifconfig  $INT

	while [ -z "$OUTPUT" ]
	do
		sleep $FEW_SECONDS

		if [ "$TIME" -gt "$TMO" ]; then
			
			echo "Exiting on H-timeout"

			exit -3
		fi

		TIME=$((TIME+FEW_SECONDS))

		OUTPUT=$( mini_iw_curl | grep "$HTTP_PACKET_MARKER")		

	done	
	
	echo "RECEIVED HTTP-RESPONCE FROM $ESSID_MARKER"
	

}

wait_link()
{
	while [ -z "$OUTPUT_W" ]
	do
		sleep $FEW_SECONDS_W

		if [ "$TIME_W" -gt "$TMO_W" ]; then
			
			echo "Exiting on W-timeout"

			exit -2
		fi

		TIME_W=$((TIME_W+FEW_SECONDS_W))

		OUTPUT_W=$( mini_iw_scan | grep "$ESSID_MARKER")		

	done	
	
	echo "$ESSID_MARKER ON AIR"
}
	

connect_radio()
{

	dhclient $INT -r
	ifconfig $INT down

	iwconfig $INT mode managed essid "$ESSID"
	ifconfig $INT up

	while [ -z "$OUTPUT_C" ]
	do
		ifconfig $INT down
		sleep $FEW_SECONDS



		if [ "$TIME_C" -gt "$TMO_C" ]; then
			
			echo "Exiting on C-timeout"

			exit -1
		fi


		kill $(ps aux | grep -E 'wpa_supplicant' | awk '{print $2}') 

		ifconfig $INT up

		iw wlan0 scan >>./_$ESSID_MARKER.LOG

		# Don't interact with shell (just sit and onserve only)
		echo -e "12345678\n12345678" | wpa_passphrase WIFIPASSWORD_24 > /_M.conf


		wpa_supplicant -B -D wext -i wlan0 -c /_M.conf 2>/dev/null

		TIME_C=$((TIME_C+FEW_SECONDS))

		# Let the air connection to stabilize. TODO: check is right interval?
		sleep 3

		OUTPUT_C=$( mini_iw_link | grep "$ESSID_MARKER")		

	done	
	
	echo "ESTABLISHED RADIO LINK TO $ESSID_MARKER"

}

# Kill previously started processes once we're interrupted this script eaelier with CTRL+C, or sort of that
kill $(ps aux | grep -E 'dhclient' | awk '{print $2}') 

# Connect to DUT/CPE
connect_radio

# Ensure the link has adopted by the local system before polling HTTP server
wait_link

# Ask HTTP webserver for at least 1 correct responce
poll_webserver 

# Right place to go out; any other can leave in process tree not terminated processes/daemons
exit

