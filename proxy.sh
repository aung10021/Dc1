#!/bin/bash

USERIPCONF="userip.conf"
PROXYCONF="proxy_conf.conf"
FORWARD="forward.conf"

declare -a usernames
declare -a userpwds
declare -a ipaddresses
declare -a iplist
htpasswd=$(which htpasswd)
if [ -z $htpasswd ]; then
sudo /usr/bin/apt update
sudo /usr/bin/apt -y install apache2-utils
fi

squid=$(which squid)
if [ -z $squid ]; then
sudo /usr/bin/apt update
sudo /usr/bin/apt -y install squid
fi

cp squid.conf /etc/squid/squid.conf -f

while read option param0 param1 param2
do
	if [ ! -z $option ] &&  [ ${option:0:1} != "#" ]
	then
		case $option in
			"USER")
				usernames+=($param0)
				userpwds+=($param1)
				ipaddresses+=("$param2")
				;;
			*)
				export "$option"="$param0"
				;;
		esac		

	fi
done < ./$PROXYCONF

echo -n>$USERIPCONF

#create userip file

sudo chmod 777 /etc/squid/passwd
echo -n>/etc/squid/passwd

echo -n>$FORWARD

for index in ${!usernames[@]}
do
 username=${usernames[$index]}
 userpwd=${userpwds[$index]}

 /usr/bin/htpasswd -b /etc/squid/passwd $username $userpwd

 ipaddress=${ipaddresses[$index]}
 
 IFS=' ' read -ra ips <<< $ipaddress
 for ip in ${ips[@]}
 do
    if [[ $ip == *"-"* ]]; then
       IFS='-' read -ra sip <<< $ip
    	startIP=${sip[0]}
    	endIP=${sip[1]}
    
    	IFS='.' read -ra startIP_arr <<< $startIP
	IFS='.' read -ra endIP_arr <<< $endIP

	for ((i=${startIP_arr[3]}; i<=${endIP_arr[3]};i++)); do
	   echo "${startIP_arr[0]}.${startIP_arr[1]}.${startIP_arr[2]}.$i $username">>$USERIPCONF
           iplist+=(${startIP_arr[0]}.${startIP_arr[1]}.${startIP_arr[2]}.$i)
	done
    else
       echo "$ip $username">>$USERIPCONF
       iplist+=($ip)
    fi
 done 
done

sudo cp $USERIPCONF /etc/squid/userip.conf

#Bind ipaddress list to Ethernet

for i in ${!iplist[@]}; do
  sudo ip addr add ${iplist[$i]}/$NETMASK dev $DEV 2>/dev/null

  echo "acl ip$i myip ${iplist[$i]}">>$FORWARD
  echo "tcp_outgoing_address ${iplist[$i]} ip$i">>$FORWARD
done

sudo cp $FORWARD /etc/squid/$FORWARD

#sudo /sbin/iptables -I INPUT -p tcp --dport 3128 -j ACCEPT
#sudo /sbin/iptables-save

echo "squid restarting..."
sudo service squid restart
echo "squid restarted"

sudo iptables -P FORWARD ACCEPT
sudo iptables -F

( crontab -l | grep -v -F "/etc/squid/monitor_squid.sh") | crontab -
crontab -l > mycron
echo "* * * * * /etc/squid/monitor_squid.sh" >> mycron
crontab mycron
rm mycron
