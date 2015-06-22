#!/bin/bash

all="ca
jv
uk
us";

usage () {
cat << EOF
    Usage: `basename $0` p_and_l__code;
    Pass in the 'P&L' (us, jv, uk, ca, au) to this script to show Londiste Provider status.
EOF
    exit 1;
}

# This script will find the associated cnuapp provider cluster/server in the cluster file from the cnuapp_list.pl script.
# Then it will run the londiste status command on each cluster and return the portion containing the statuses of the associated subscribers.
# Good way to cross check that you are releasing to all the 'known' subscribers.
# Pass in a period '.' to get all the cnuapp providers.
# Caution: this was written specifically for Skytools3, it will NOT work for Skytools2.

[[ $# -eq 0 ]] && usage ;

_pnl=`echo $1 | tr '[A-Z]' '[a-z]'`;
if [ "$_pnl" == "." ]
then 
	_pnl=$all;
fi

IFS='
';

function get_subscriber_info {
	subscriber=`ssh -q $subserver "PGUSER=postgres PGCLUSTER=$subcluster psql $db --tuples-only --command \"set role su; select 'Subscriber: '||pgq_node.get_subscriber_info('$q')||',  Provider: $subcluster on $subserver'  \" "`;
	if [ "$subscriber" != "" ]
	then
		echo "$subscriber";
	fi
}

for pnl in $_pnl
do
	entry=`perl cnuapp_list.pl --role=provider --pnl=$pnl`
	server=`echo $entry | cut -d' ' -f1`;
	provider_cluster=`echo $entry | cut -d' ' -f2 | cut -d '/' -f2`;  # get cluster name sans version
	echo "P&L: $pnl";
	provider=`ssh -q $server "ps aux | grep 'londiste.*$provider_cluster.*worker' | grep -v grep | tr -s ' ' | cut -d' ' -f12-99 | sed -e 's/worker.*$/status/'"`
	echo "$provider on $server:";
	cluster=`echo $entry | cut -d' ' -f2`;
	db=`echo $entry | cut -d' ' -f3`;
	for line in `ssh -q $server "sudo -u skytools $provider"`
	do
		echo $line;
		x=`echo $line | awk '{print $1}'`;
		if [ "$x" == "Queue:" ]
		then
			q=`echo $line | awk '{print $2}'`;
		fi
	done;

	echo " ";
	echo "--> pgq_node.get_subscriber_info('$q') on all clusters...";

	subserver=$server;
	subcluster=$cluster;
	get_subscriber_info;

	_subentry=`perl cnuapp_list.pl --role=subscriber --pnl=$pnl`
	for subentry in $_subentry
	do
		subserver=`echo $subentry | cut -d' ' -f1`;
		subcluster=`echo $subentry | cut -d' ' -f2`;
		get_subscriber_info;
	done
	echo " ";
done;
