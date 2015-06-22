#!/bin/bash

# This script will get each distinct server that has a cnuapp cluster and attempt to ssh and execute an echo command.
# Each server will be listed and if the echo works, then it shows 'success' and adds to the good-connection count. 
# Otherwise, it should show the connection error and the 'not successful' status and add to the bad-connection count.
# Totals are shown at the end of: all servers, good connections and bad connections.


total=0;
good=0;
bad=0;

for line in `perl cnuapp_list.pl --servers_only`
do
  server=$line;
	let "total+=1";
	echo -n "Trying: $server ... ";
	reply='';
	x=`ssh $server "echo ''" > .test_ssh.out 2>&1`;
	reply=`cat .test_ssh.out | grep -v '^\=.*=$' | grep -v '^$'`;
	if [ "$reply" = "" ]
	then
		echo "Success.";
		let "good+=1";
	else
		if [[ "$reply" =~ "Warning" ]]
		then
			echo $reply;
			let "good+=1";
		else
			echo "NOT successful: $reply";
			let "bad+=1";
		fi
	fi
done;
echo " ";
echo "Results Summary:";
echo "	Total Attempted  = $total";
echo "	Good Connections = $good";
echo "	Bad Connections  = $bad";
echo " ";
rm .test_ssh.out;
