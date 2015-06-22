#!/bin/bash

in_platform=$1;
in_query=$2;
doit=$3;
if [ "$doit" != "vamos" ]
then
	echo "Dry Run...";
fi

function parse_exec 
{
	server=`echo $line | cut -d' ' -f1`;
	cluster=`echo $line | cut -d' ' -f2`;
	db=`echo $line | cut -d' ' -f3`;
	if [ "$doit" == "vamos" ]
	then
		echo "Executing in $db database ($cluster cluster) on $server server:";
		ssh -qt $server "PGCLUSTER=$cluster PGUSER=postgres psql $db --command \"$in_query \" ";
	else #dry run is default mode
		echo ssh -qt $server '"'PGCLUSTER=$cluster PGUSER=postgres psql $db --command \\\"$in_query \\\" '"';
	fi
}
IFS='
';

if [ $in_platform != "8b" ]
then
  for line in `perl cnuapp_list.pl --pnl=$in_platform | sort -t' ' -k2 | grep $in_platform-`
  do
    parse_exec;
  done;
else
  for line in `perl 8box_list.pl --role=provider | sort -t' ' -k2`
  do
    parse_exec;
  done;
fi
