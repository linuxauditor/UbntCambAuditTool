#!/bin/bash

#checks to make sure that we have all installed programs locally.

export PATH="/usr/sbin:/sbin:/usr/bin:/bin"

for PROGRAM in \
  awk     \
  cat     \
  cp      \
  id      \
  date    \
  grep    \
  mkdir   \
  mv      \
  rm      \
  sed     \
  ssh     \
  expect  \
  timeout \
  tr      \
  curl    \
  cut     \
  
  
do
if ! hash "${PROGRAM}" 2>/dev/null ; then
	printf  "[-] error: command not found in PATH: %s\n" "${PROGRAM}" >&2
	exit 1
fi

done


#Retrieve Ubiquiti radio data

getUbnt () {

#Usage <host IP address>  <SSH port>  <http(s) port>

printf "$1" is Ubnt, getting FWversion

#Legacy radios running 4.0.4 XS versions of firmware must have manually configured.  We can identify this by dumping stderr out to below file.  Timeout taped here because we don't want ssh to timeout not entering password.
/usr/bin/timeout 5 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $1 -p $2 2> ./workspace/sshError

#if sshError contains "RSA" (not trusted host) or is empty (you have sshed into host from your PC and typed "yes" for trusting host key) 
if grep "Permanently added" ./workspace/sshError ; then	
	#get via SCP trying all commonly used passwords that we have.  If file not retrieved (assumed to be authentication failure), then try next password.
	printf "nonlegacy"

	printf "trying foo"
	/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/etc/version"
	password='foo'

	if [ ! -e ./workspace/version ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/etc/version"
		password='foo'

	fi

	if [ ! -e ./workspace/version ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/etc/version"
		password='foo'

	fi

	if [ ! -e ./workspace/version ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/etc/version"
		password='foo'

	fi

	if [ ! -e ./workspace/version ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/etc/version"
		password='foo'

	fi
	
	if [ -e ./workspace/version ]; then

		#parse out XW/XCv.'fwsuffix'.XX, we only want to know the main version (eg. 4,5,6,8) to identify if it is AirOS or AC radio.  Returns integer.
		fwSuffix=$( sed 's/^.*v//' ./workspace/version | cut -c 1 )

		#we will need this later.
		fwVersion=$(cat ./workspace/version)

		rm ./workspace/version

		#checks OS of host in question, calls correct function based off FW version or it logs.  AirOS and AC are not the same.
		if [ $fwSuffix -eq 5 ] || [ $fwSuffix -eq 6 ]; then
			printf "$1" "$2" "$3"
			getUbntAirOs "$1" "$2" "$3" "$password" "$4"
	
		elif [ $fwSuffix -eq 8 ]; then
			getUbntAC "$1" "$2" "$3" "$password" "$4"

		#If the script has made it this far we are dealing with an M radio running 4.0.4 which can be gathered using the 	
		elif [ $fwSuffix -eq 4 ]; then
			getUbntM4 "$1" "$2" "$3" "$password"
	
		else	
			printf "$1 Invalid fwVersion"
			printf "$1","19 - Ubiquiti Invalid fwVersion $fwVersion" >> ./output/error.temp
			return 1
		
		fi

	#assuming authentication failure... as we have no business here anymore.	

	else
		printf "exiting $host with authentication error"
		printf "$1","20 - Ubiquiti RSA ssh authentication failure port $2" >> ./output/error.temp

	fi

elif grep 'diffie-hellman-group1' ./workspace/sshError ; then

	#get via SCP trying all commonly used passwords that we have.  If file not retrieved (assumed to be authentication failure), then try next password.
	printf "trying foo"
	/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/tmp/running.cfg"
	password='foo'

	if [ ! -e ./workspace/running.cfg ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/tmp/running.cfg"
		password='foo'

	fi

	if [ ! -e ./workspace/running.cfg ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/tmp/running.cfg"
		password='foo'

	fi

	if [ ! -e ./workspace/running.cfg ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/tmp/running.cfg"
		password='foo'

	fi

	if [ ! -e ./workspace/running.cfg ]; then
		printf "trying foo"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" 'foo' "$2" "/tmp/running.cfg"
		password='foo'

	fi

	if [ -e ./workspace/running.cfg ] ; then

		printf "Legacy v4 radio authentication succeeded"
		/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" "$password" "$2" "/usr/lib/version"
		getUbnt4 "$1" "$2" "$3" "$password" "$4"


	else
		printf "exiting $host with authentication error"
		printf "$1","27 - Ubiquiti DFG ssh authentication failure port $2" >> ./output/error.temp

	fi

fi

}

getUbntAirOs () {
#Usage  <host IP address>  <SSH port>  <http(s) port>  <password>

/usr/bin/timeout 5 /usr/bin/expect ./sshUBNT.expect "$1" "$4" "$2" "mca-status > /tmp/mca-status"
/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" "$4" "$2" "/tmp/mca-status"
/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" "$4" "$2" "/tmp/running.cfg"

#ugly and even uglier parsing, just got this working and moved on... Could be cleaned up
device=$(grep deviceName ./workspace/mca-status | sed -e 's/.*platform=\(.*\)deviceIp.*/\1/'| tr -d \,)
hName=$(grep deviceName ./workspace/mca-status | sed -e 's/.*Name=\(.*\)deviceId.*/\1/' | tr -d \,)
hAddress=$(grep deviceName ./workspace/mca-status | sed -e 's/.*Id=\(.*\)firmware.*/\1/' | tr -d \,)
eSSID=$(grep essid ./workspace/mca-status | sed 's/.*essid=\(.*\)/\1/' | tr -d \,)
latitude=$(grep latitude ./workspace/mca-status | sed 's/.*latitude=\(.*\)/\1/' | tr -d \,)
longitude=$(grep longitude ./workspace/mca-status | sed 's/.*longitude=\(.*\)/\1/' | tr -d \,)
distance=$(grep distance ./workspace/mca-status | awk -F "=" '{ print $2 }')
nMode=$(grep wlanOpmode ./workspace/mca-status | sed 's/.*wlanOpmode=\(.*\)/\1/' | tr -d \,)
countryCode=$(grep radio.countrycode ./workspace/running.cfg | awk -F "=" '{ print $2 }')

#if host is AP we want to get parent child data.
if [[ $nMode == *'ap'* ]] ;then

	printf "$host" is an AP

	#call expect script
	/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" "$4" "$2" "/tmp/stats/wstalist"

	#setting  counter for while loop
	k="1"

	#counting number of unique MAC addresses in wstalist
	i=$(grep -c '"mac"' ./workspace/wstalist)

	#while loop for each host
	while [ "$k" -le "$i" ]
	do
		#for each k value, retrieve that instance of match and parse
		childIp=$(grep -m "$k" '"lastip"' ./workspace/wstalist | tail -n 1 | awk '{ print $2 }' | tr -d \" | tr -d \,)
		childName=$(grep -m "$k" '"name"' ./workspace/wstalist | tail -n 1 | awk '{ print $2 }' | tr -d \" | tr -d \,)
		childMAC=$(grep -m "$k" '"mac"' ./workspace/wstalist | tail -n 1 | awk '{ print $2 }' | tr -d \" | tr -d \,)
		childType=$(grep -m "$k" '"platform"' ./workspace/wstalist | tail -n 1 | awk '{ print $2,$3 }' | tr -d \" | tr -d \,)

		#append to parent child csv
		printf "$host,""$hName,""$device,""$eSSID,""$childName,""$childIp,""$childMAC,""$childType," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/parentChild.csv

		#add 1 to counter
		k=$((k+1))

	done

else
    print "$host is not an AP"
fi

#Traffic Shape information
if grep tshaper ./workspace/running.cfg ; then

	if grep -m 1 -q "tshaper.status=enabled" ./workspace/running.cfg ; then
		trafficShape=$(printf "configured - Enabled")
		x=1
		z=$(grep "tshaper.[0-9].devname" ./workspace/running.cfg | awk -F "." '{ print $2 }' | tail -n 1)

		while [ "$x" -le "$z" ]; do
			dev=$(grep "tshaper.$x.devname" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			devStatus=$(grep "tshaper.$x.input.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			in=$(grep "tshaper.$x.input.rate" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			inBurst=$(grep "tshaper.$x.input.burst" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			out=$(grep "tshaper.$x.output.rate" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			outBurst=$(grep "tshaper.$x.output.burst" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			inStatus=$(grep "tshaper.$x.input.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			outStatus=$(grep "tshaper.$x.output.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')

			printf "$1,$hName,$eSSID,$dev,$devStatus,$inStatus,$in,$inBurst,$outStatus,$out,$outBurst," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/shape.csv
			x=$((x+1))
		done

	else
		trafficShape=$(printf "configured - Not Enabled")
	fi

else
    trafficShape=$(printf "not Configured - Disabled")

fi


#Appending data to CSV
printf "$1,Ubiquiti,$hAddress,$device,$fwVersion,$hName,$eSSID,$latitude,$longitude,$countryCode,$trafficShape,$3,$4,$nMode,$distance,$t22,$t10001,$t2002," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/radioData.temp


}



getUbntAC () {

#Usage  <host IP address>  <SSH port>  <http(s) port>  <password>

/usr/bin/timeout 5 /usr/bin/expect ./sshUBNT.expect "$1" "$4" "$2" "mca-status > /tmp/mca-status"
/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" "$4" "$2" "/tmp/mca-status"
/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" "$4" "$2" "/tmp/running.cfg"

#ugly and even uglier parsing, just got this working and moved on... Could be cleaned up
device=$(grep deviceName ./workspace/mca-status | sed -e 's/.*platform=\(.*\)deviceIp.*/\1/'| tr -d \,)
hName=$(grep deviceName ./workspace/mca-status | sed -e 's/.*Name=\(.*\)deviceId.*/\1/' | tr -d \,)
hAddress=$(grep deviceName ./workspace/mca-status | sed -e 's/.*Id=\(.*\)firmware.*/\1/' | tr -d \,)
eSSID=$(grep essid ./workspace/mca-status | sed 's/.*essid=\(.*\)/\1/' | tr -d \,)
latitude=$(grep latitude ./workspace/mca-status | sed 's/.*latitude=\(.*\)/\1/' | tr -d \,)
longitude=$(grep longitude ./workspace/mca-status | sed 's/.*longitude=\(.*\)/\1/' | tr -d \,)
distance=$(grep distance ./workspace/mca-status | awk -F "=" '{ print $2 }')
nMode=$(grep wlanOpmode ./workspace/mca-status | sed 's/.*wlanOpmode=\(.*\)/\1/' | tr -d \,)
countryCode=$(grep radio.countrycode ./workspace/running.cfg | awk -F "=" '{ print $2 }')

#if host is AP we want to get parent child data.
if [[ $nMode == *'ap'* ]] ;then

	#in order for scp script to work we need to trim all backslashes from $password variable.
	password=$(printf $password | tr -d \\)

	printf "$host" is an AP

	#call expect script
	/usr/bin/timeout 5 /usr/bin/expect ./sshUBNT.expect "$1" "$4" "$2" "wstalist -p > /tmp/wstalist"
	/usr/bin/timeout 5 /usr/bin/expect ./scpAP.expect "$1" "$4" "$2" "/tmp/wstalist"

	#setting  counter for while loop
	k="1"

	#counting number of unique MAC addresses in wstalist
	i=$(grep -c '"mac"' ./workspace/wstalist)

	#while loop for each host
	while [ "$k" -le "$i" ]
	do
		#for each k value, retrieve that instance of match and parse
		childIp=$(grep -m "$k" '"lastip"' ./workspace/wstalist | tail -n 1 | awk -F ":" '{ print $2 }' | tr -d \" | tr -d \,)
		childName=$(grep -m "$k" '"hostname"' ./workspace/wstalist | tail -n 1 | awk -F ":" '{ print $2 }' | tr -d \" | tr -d \,)
		childMAC=$(grep -m "$k" '"mac"' ./workspace/wstalist | tail -n 1 | tr -d \" | tr -d \, | sed 's/.*mac:\(.*\)/\1/')
		childType=$(grep -m "$k" '"platform"' ./workspace/wstalist | tail -n 1 | awk -F ":" '{ print $2 }' | tr -d \" | tr -d \,)

		#append to parent child csv
		printf "$host,""$hName,""$device,""$eSSID,""$childName,""$childIp,""$childMAC,""$childType," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/parentChild.csv


		#add 1 to counter
		k=$((k+1))

	done

else
    printf "$host is not an AP"

fi


#Traffic Shape information
if grep tshaper ./workspace/running.cfg ; then

	if grep -m 1 -q "tshaper.status=enabled" ./workspace/running.cfg ; then
		trafficShape=$(printf "configured - Enabled")
		x=1
		z=$(grep "tshaper.[0-9].devname" ./workspace/running.cfg | awk -F "." '{ print $2 }' | tail -n 1)

		while [ "$x" -le "$z" ]; do
			dev=$(grep "tshaper.$x.devname" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			devStatus=$(grep "tshaper.$x.input.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			in=$(grep "tshaper.$x.input.rate" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			inBurst=$(grep "tshaper.$x.input.burst" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			out=$(grep "tshaper.$x.output.rate" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			outBurst=$(grep "tshaper.$x.output.burst" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			inStatus=$(grep "tshaper.$x.input.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			outStatus=$(grep "tshaper.$x.output.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')

			printf "$1,$hName,$eSSID,$dev,$devStatus,$inStatus,$in,$inBurst,$outStatus,$out,$outBurst," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/shape.csv
			x=$((x+1))
		done

	else
		trafficShape=$(printf "configured - Not Enabled")
	fi

else
    trafficShape=$(printf "not Configured - Disabled")

fi

#Appending radio data to CSV
printf "$1,Ubiquiti,$hAddress,$device,$fwVersion,$hName,$eSSID,$latitude,$longitude,$countryCode,$trafficShape,$3,$4,$nMode,$distance,$t22,$t10001,$t2002," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/radioData.temp

}


getCambium () {

#Usage <host IP address>  <SSH port>  <http(s) port>

printf "getCambium"

printf "trying foo"
/usr/bin/timeout 5 /usr/bin/expect ./sshCamb.expect "$1" 'foo' "22" "show dashboard" "show config" > ./workspace/Cambium
password='foo'

if grep 'denied' ./workspace/Cambium ; then
	printf "trying foo"
	/usr/bin/timeout 5 /usr/bin/expect ./sshCamb.expect "$1" 'foo' "22" "show dashboard" "show config" > ./workspace/Cambium
	password='foo'

fi

if grep 'denied' ./workspace/Cambium ; then
	printf "trying foo"
	/usr/bin/timeout 5 /usr/bin/expect ./sshCamb.expect "$1" 'foo' "22" "show dashboard" "show config" > ./workspace/Cambium
	password='foo'

fi

if grep 'WirelessMACAddress' ./workspace/Cambium ; then
	parseCambium "$1" "NULL" "$3"

else
	printf "$1", "21 - Cambium expect script not working" >> ./output/error.temp

fi

}

parseCambium () {

hAddress=$(grep 'WirelessMACAddress' ./workspace/Cambium | awk '{ print $2 }' )
device=$(grep 'EffectiveDeviceName' ./workspace/Cambium | awk '{ print $2 }' )
fwVersion=$(grep 'CurrentuImageVersion' ./workspace/Cambium | awk '{ print $2 }' )
hName=$(grep 'EffectiveDeviceName' ./workspace/Cambium | awk '{ print $2 }' )
eSSID=$(grep 'EffectiveSSID' ./workspace/Cambium | awk '{ print $2 }' )
latitude=$(grep 'DeviceLatitude' ./workspace/Cambium | awk '{ print $2 }' )
longitude=$(grep 'DeviceLongitude' ./workspace/Cambium | awk '{ print $2 }' )
nMode=$(grep 'DeviceMode' ./workspace/Cambium | awk '{ print $2 }' )
distance=$(grep 'STADistanceMil' ./workspace/Cambium | awk '{ print $2 }' )

printf "$1,Cambium,$hAddress,$device,$fwVersion,$hName,$eSSID,$latitude,$longitude,countryCode,tShaping,$3,$password,$nMode,$distance,$t22,$t10001,$t2002," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/radioData.temp

}

getMikro () {

	printf "getMikro"

	printf $1,"22 Mikro Equipment" >> ./output/error.temp

}

getTranzeo () {

	printf "getTranzeo"

	printf $1,"23 Tranzeo Equipment" >> ./output/error.temp

}


getUbntM4 () {

	printf "getUbntM4"

	printf $1,"24 Ubiquiti Mv4 Equipment" >> ./output/error.temp

}

getUbnt4 () {

printf "getUbnt4"

device=$(grep deviceName ./workspace/running.cfg | sed -e 's/.*platform=\(.*\)deviceIp.*/\1/'| tr -d \,)
hName=$(grep resolv.host.1.name ./workspace/running.cfg | awk -F "=" '{ print $2 }')
eSSID=$(grep wireless.1.ssid ./workspace/running.cfg | awk -F "=" '{ print $2 }')
latitude=$(grep system.latitude ./workspace/running.cfg | awk -F "=" '{ print $2 }')
longitude=$(grep system.longitude ./workspace/running.cfg | awk -F "=" '{ print $2 }')
distance=$(grep radio.1.ackdistance ./workspace/running.cfg | awk -F "=" '{ print $2 }')
nMode=$(grep netmode ./workspace/running.cfg | awk -F "=" '{ print $2 }')
fwVersion=$(cat ./workspace/version)
countryCode=$(grep radio.countrycode ./workspace/running.cfg | awk -F "=" '{ print $2 }')

###hAddress=$(grep deviceName ./workspace/running.cfg | sed -e 's/.*Id=\(.*\)firmware.*/\1/' | tr -d \,)
###device=$(grep deviceName ./workspace/running.cfg | sed -e 's/.*platform=\(.*\)deviceIp.*/\1/'| tr -d \,)
#"ipAddress,manufacturer,macAddress,model,firmware,hostname,eSSID,latitude,longitude,countryCode,tShaping,httpPort,pass,mode,distanceMiles,port22,port10001,port2002,"

if grep tshaper ./workspace/running.cfg ; then


	if grep -m 1 -q "tshaper.status=enabled" ./workspace/running.cfg ; then
		trafficShape=$(printf "configured - Enabled")

		x=1
		z=$(grep "tshaper.[0-9].devname" ./workspace/running.cfg | awk -F "." '{ print $2 }' | tail -n 1)

		while [ "$x" -le "$z" ]; do

			dev=$(grep "tshaper.$x.devname" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			devStatus=$(grep "tshaper.$x.input.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			in=$(grep "tshaper.$x.input.rate" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			inBurst=$(grep "tshaper.$x.input.burst" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			out=$(grep "tshaper.$x.output.rate" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			outBurst=$(grep "tshaper.$x.output.burst" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			inStatus=$(grep "tshaper.$x.input.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')
			outStatus=$(grep "tshaper.$x.output.status" ./workspace/running.cfg | awk -F "=" '{ print $2 }')

			printf "$1,$hName,$eSSID,$dev,$devStatus,$inStatus,$in,$inBurst,$outStatus,$out,$outBurst," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/shape.csv
			x=$((x+1))
		done

	else
		trafficShape=$(printf "configured - Not Enabled")
	fi
	

else
	trafficShape=$(printf "not Configured - Disabled")

fi

printf "$1,Ubiquiti,foo,Ubiquiti,$fwVersion,$hName,$eSSID,$latitude,$longitude,$countryCode,$trafficShape,$3,$4,$nMode,$distance,$t22,$t10001,$t2002," | tr -d '\040\011\012\015' | sed 's/$/\n/' >> ./output/radioData.temp


}

getList () {

#count lines in list of IP addresses
j=$(wc ./list | awk ' {print $1} ')

#set counter to 1
l=1

printf "$l" "$j"

#while counter is less than or equal to number of lines; 
while [ "$l" -le "$j" ] ;  do
	rm ./workspace/*

	#retrieves counter value's corresponding line from beginning to end
	host=$(sed "${l}q;d" ./list)

	#ping host
	ping -w 2 -c 1 $host > /dev/null

	#if exit code equal succesful then...
	if [ $? -eq 0 ] ;  then

		printf "$host is online"

		#nmap the ports that we are interested in, set string (open or NULL)
		t443=$(nmap -p T:443 $host | grep open | awk '{ print $2 }' )
		t8090=$(nmap -p T:8090 $host | grep open | awk '{ print $2 }' )
		t80=$(nmap -p T:80 $host | grep open | awk '{ print $2 }' )
		t22=$(nmap -p T:22 $host | grep open | awk '{ print $2 }' )
		t10001=$(nmap -p T:10001 $host | grep open | awk '{ print $2 }' )
		t2002=$(nmap -p T:2002 $host | grep open | awk '{ print $2 }' )

		#you can figure this one out
		if [ "$t8090" == "open" ] ; then

			printf "$host port 8090 is open"

			#timeout for curl to retrieve login/main page, set StdOut to homePage
			(/usr/bin/timeout 10 curl -k -v -L  -c /tmp/cookies.txt "http://$host:8090") > ./workspace/loginpage.txt

			#if homePage contains "ubnt or airos or etc..." then, else if ambium, else if ranzeo etc....;
			if  grep -m 1 -q "ubnt" ./workspace/loginpage.txt || grep -m 1 -q "airos" ./workspace/loginpage.txt || grep -m 1 -q "biquiti" ./workspace/loginpage.txt || grep -m 1 -q "ulogo.gif" ./workspace/loginpage.txt ; then
				printf "radio is ubnt"

				#we need to identify ssh port, call ubnt function based on what ssh port is open
				if [ "$t22" = "open" ] ; then
					getUbnt "$host" "22" "8090"

				elif [ "$t2002" = "open" ] ; then
					getUbnt "$host" "2002" "8090"

				else
					printf $host,"1 Ubiquiti no ssh port open. Http port is 8090" >> ./output/error.temp

				fi

			elif grep -m 1 -q "ambium" ./workspace/loginpage.txt || grep -m 1 -q "ePMP" ./workspace/loginpage.txt ; then
				printf "radio is cambium"

				#we need to identify ssh port, call Cambium function based on what ssh port is open
				if [ "$t22" = "open" ] ; then
					getCambium "$host" "22" "8090"

				elif [ "$t2002" = "open" ] ; then
					getCambium "$host" "2002" "8090"

				else
					printf $host,"2 Cambium no ssh port open. Http port is 8090" >> ./output/error.temp

				fi

			elif  grep -m 1 -q "ranzeo" ./workspace/loginpage.txt ; then	

				#we need to identify ssh port, call Tranzeo function based on what ssh port is open
				printf "radio is tranzeo"
				if [ "$t22" = "open" ] ; then
					getTrans "$host" "22" "8090"

				elif [ "$t2002" = "open" ] ; then
					getTrans "$host" "2002" "8090"

				else
					printf $host,"3 Tranzeo no ssh port open. Http port is 8090" >> ./output/error.temp

				fi

			elif grep -m 1 -q "ikrotik" ./workspace/loginpage.txt ; then
				printf "radio is Mikrotik"
				if [ "$t22" = "open" ] ; then
					getMikro "$host" "22" "8090"

				elif [ "$t2002" = "open" ] ; then
					getMikro "$host" "2002" "8090"

				else
					printf $host,"4 Mikrotik no ssh port open. Http port is 8090" >> ./output/error.temp

				fi

			else 				
				printf "$host","5 device identification failed port 8090" >> ./output/error.temp

			fi

		fi

		#you can figure this one out
		if [ "$t80" == "open" ] ; then

			printf "$host port 80 is open"
			/usr/bin/timeout 10 curl -k -t 10 -c /tmp/cookies.txt -L "http://$host:80/" > ./workspace/loginpage.txt

			if  grep -m 1 -q "ubnt" ./workspace/loginpage.txt || grep -m 1 -q "airos" ./workspace/loginpage.txt || grep -m 1 -q "biquiti" ./workspace/loginpage.txt || grep -m 1 -q "ulogo.gif" ./workspace/loginpage.txt ; then
				printf "radio is ubnt"

				if [ "$t22" = "open" ] ; then
					getUbnt "$host" "22" "80"

				elif [ "$t2002" = "open" ] ; then
					getUbnt "$host" "2002" "80"

				else 
					printf $host,"6 Ubiquiti no ssh port open. Http port is 80" >> ./output/error.temp

				fi

			elif grep -m 1 -q "ambium" ./workspace/loginpage.txt || grep -m 1 -q "ePMP" ./workspace/loginpage.txt ; then
				printf "radio is cambium"

				if [ "$t22" = "open" ] ; then
					getCambium "$host" "22" "80"

				elif [ "$t2002" = "open" ] ; then
					getCambium "$host" "2002" "80"

				else
					printf $host,"7 Cambium no ssh port open. Http port is 80" >> ./output/error.temp

				fi

			elif  grep -m 1 -q "ranzeo" ./workspace/loginpage.txt ; then
				printf "radio is tranzeo"
				if [ "$t22" = "open" ] ; then
					getTrans "$host" "22" "80"

				elif [ "$t2002" = "open" ] ; then
						getTrans "$host" "2002" "80"

				else
					printf $host,"8 Tranzeo no ssh port open. Http port is 80" >> ./output/error.temp

				fi

			elif grep -m 1 -q "ikrotik" ./workspace/loginpage.txt ; then
				printf "radio is Mikrotik"
				if [ "$t22" = "open" ] ; then
					getMikro "$host" "22" "80"

				elif [ "$t2002" = "open" ] ; then
					getMikro "$host" "2002" "80"

				else
					printf $host,"9 Mikrotik no ssh port open. Http port is 80" >> ./output/error.temp

				fi
			else 				
				printf "$host","10 device identification failed port 80" >> ./output/error.temp

			fi

		fi

		#you can figure this one out
		if [ "$t443" == "open" ] ; then

			printf "$host port 80 is open"
			/usr/bin/timeout 10 curl -k -t 10 -c /tmp/cookies.txt -L "https://$host:443/" > ./workspace/loginpage.txt

			if  grep -m 1 -q "ubnt" ./workspace/loginpage.txt || grep -m 1 -q "airos" ./workspace/loginpage.txt || grep -m 1 -q "biquiti" ./workspace/loginpage.txt || grep -m 1 -q "ulogo.gif" ./workspace/loginpage.txt ; then
				printf "radio is ubnt"

				if [ "$t22" = "open" ] ; then
					getUbnt "$host" "22" "443"

				elif [ "$t2002" = "open" ] ; then
					getUbnt "$host" "2002" "443"

				else 
					printf $host,"11 Ubiquiti no ssh port open. Http port is 443" >> ./output/error.temp

				fi

			elif grep -m 1 -q "ambium" ./workspace/loginpage.txt || grep -m 1 -q "ePMP" ./workspace/loginpage.txt ; then
				printf "radio is cambium"

				if [ "$t22" = "open" ] ; then
					getCambium "$host" "22" "443"

				elif [ "$t2002" = "open" ] ; then
					getCambium "$host" "2002" "443"

				else
					printf $host,"12 Cambium no ssh port open. Http port is 443" >> ./output/error.temp

				fi

			elif  grep -m 1 -q "ranzeo" ./workspace/loginpage.txt ; then
				printf "radio is tranzeo"
				if [ "$t22" = "open" ] ; then
					getTrans "$host" "22" "443"

				elif [ "$t2002" = "open" ] ; then
					getTrans "$host" "2002" "443"

				else
					printf $host,"13 Tranzeo no ssh port open. Http port is 443" >> ./output/error.temp

				fi

			elif grep -m 1 -q "ikrotik" ./workspace/loginpage.txt ; then	
				printf "radio is Mikrotik"
				if [ "$t22" = "open" ] ; then
					getMikro "$host" "22" "443"
	
				elif [ "$t2002" = "open" ] ; then
					getMikro "$host" "2002" "443"

				else
					printf $host,"14 Mikrotik no ssh port open. Http port is 443" >> ./output/error.temp

				fi
				
			else 				
				printf "$host","15 device identification failed port 443" >> ./output/error.temp

			fi
		fi

	else

		printf "$host is offline"
		printf $host,"offline" >> ./output/error.temp
	fi
	
	l=$((l+1))
done

}

#create output directory silently
mkdir ./output &> /dev/null

#housekeeping silently in case user did not remove these files the last time around or script was exited without completing
rm ./output/* &> /dev/null

#touch ./output/logs

######

#pipe script output to file so we can search through it for debugging purposes.
#exec 2>&1 ./output/logs

######

#create output/error-log files with correct CSV header to output dir
printf "ipAddress,manufacturer,macAddress,model,firmware,hostname,eSSID,latitude,longitude,countryCode,tShaping,httpPort,pass,mode,distanceMiles,port22,port10001,port2002," > ./output/radioData.csv
printf "parent,parentHostName,parentModel,parentSSID,child,childIpAddress,childMACaddress,childType," > ./output/parentChild.csv
printf "HostIP,hostName,eSSID,Interface,interfaceStatus,inStatus,ingressThrottle,inBurst,outStatus,egressThrottle,outBurst," > ./output/shape.csv
printf "host,error," > ./output/error.csv

#call main function once using preloaded IP addresses, we will call again after first run through is done.
getList ""

#copy from first run through into output dir.  We want a copy of the first list of host for debug purposes.
cp ./list ./output/list

#parse out IPs that failed expect scripts or were offline when we were looking at them last from the error.csv file.  Overwrite the list of hosts.
cat ./output/error.temp | grep -e 'offline' -e 'expect' -e 'authen' | awk -F , '{ print $1 }' > ./list &> /dev/null

#append additional parent/child, error and fwVersion to output files
cat ./output/radioData.temp >> ./output/radioData.csv # &> /dev/null
cat ./output/parentChild.temp >> ./output/parentChild.csv # &> /dev/null
cat ./output/error.temp >> ./output/error.csv # &> /dev/null

#remove files, they will be created again by called functions
rm ./output/radioData.temp &> /dev/null
rm ./output/parentChild.temp &> /dev/null
rm ./output/error.temp &> /dev/null

#call getList function again for second try.  Some hosts may be online again or we might get better results because of expect timeouts and hung radios etc.
getList ""


#append string to end of output files to help keep things organized.
printf "2nd try," >> ./output/radioData.csv
printf "2nd try," >> ./output/parentChild.csv
printf "2nd try beware of duplicates," >> ./output/error.csv
printf "2nd try beware of duplicates," >> ./output/list

#append additional parent/child, error and fwVersion to output files
cat ./output/radioData.temp >> ./output/radioData.csv &> /dev/null
cat ./output/parentChild.temp >> ./output/parentChild.csv &> /dev/null
cat ./output/error.temp >> ./output/error.csv &> /dev/null

#remove files
rm ./output/radioData.temp &> /dev/null
rm ./output/parentChild.temp &> /dev/null
rm ./output/error.temp &> /dev/null

#define timestamp
time=$(date "+%Y%m%d_%H:%M")

mkdir ./results/$time

#rename output file to timestamp
mv ./output/* ./results/$time/
