#!/bin/bash

box=$1;
query=$2;
doit=$3;
role=provider;  # 'subscribers' are all streaming replicas of providers

if [ "$doit" != "tiod" ]
then
	echo "Dry Run...";
fi

IFS='
';
for line in `perl clusterinfo_parse.pl --cluster=$1 --role=$role | sort -t' ' -k2`
do
	server=`echo $line | cut -d' ' -f1`;
	cluster=`echo $line | cut -d' ' -f2`;
	db=`ssh -qt $server "PGCLUSTER=$cluster PGUSER=postgres psql template1 --no-align --tuples-only --command \"select datname from pg_database where datname ~ 'prod' \" " | tr -d '\\r' `;
	if [ "$doit" == "tiod" ]
	then
		echo "Executing in $db database ($cluster cluster) on $server server:";
		ssh -qt $server "PGCLUSTER=$cluster PGUSER=postgres psql $db --command \"$query \" ";
	else #dry run is default mode
		echo ssh -qt $server '"'PGCLUSTER=$cluster PGUSER=postgres psql $db --command \\\"$query \\\" '"';
	fi
done;
