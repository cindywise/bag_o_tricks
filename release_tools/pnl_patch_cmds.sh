#!/bin/bash

usage () {
cat << EOF
    Usage: `basename $0` ryyyymmdd|patch p_and_l__code [release_type]
    Script does NOT patch clusters, only generate commands you use when ready.
    Pass in:
	1) release date in ryyyymmdd format for standard release, or a offcycle/non-standard patch name, and 
	2) a 'P&L' code (ca, jv, uk, us, au) 
	3) optionally the release_type: 'offcycle', or 'standard'. No value, or invalid value, input for this parameter will default to 'standard'.
    Patch commands are output, not executed, for each associated cnuapp production cluster. 
EOF
    exit 1;
}

# This script accepts a release date for the patch directory or patch name, and accepts the P&L code to read from the cluster list.
# For Standard Release patch:
#   Must input the release date in this format: ryyyymmdd
#   The input must match the name of the tarball name used in the send_untar.sh script
#   The release date gets reformatted to match the release patch name: release_yyyy-mm-dd.sql
#   Any patch not matching the standard release names, must be considered 'offcycle' - see description in following section
#   3rd parameter is optional but you can pass 'standard', which is the default.
# For OffCycle Release patch:
#   Pass in the name of the patch, which should not include the '.sql' extension
#   Patch name should match the tarball name used in the send_untar.sh script 
#   Do Not forget to pass in the keyword 'offcycle' as the 3rd parameter to this script, otherwise you get some funky results
# P&L code is required as a 2nd input parameter.
# For each of the P&L''s cluster, ssh statements are generated to be able to execute the release patch remotely.
# Important Note: if a patch is blocked, canceling (via control c) the ssh command may not cancel the sql command in the target database. You may have to open a psql session to that database to actually kill the process.

[[ $# -lt 2 ]] && usage ;

dir=$1;
pnl=`echo $2 | tr '[A-Z]' '[a-z]'`;
release_type=$3;

if [ -z "$3" ] || [ "$3" != "offcycle" ]
then
	release_type="standard";
fi

if [ "$release_type" = "standard" ]
then
	patch="release_${dir:1:4}-${dir:5:2}-${dir:7:2}";
else
	patch=$dir;
fi

cmd_sequence=1;
total_clusters=`perl cnuapp_list.pl --pnl=$pnl | wc -l`;

function make_cmds {
	server=`echo $line | cut -d' ' -f1`;
	cluster=`echo $line | cut -d' ' -f2`;
	db=`echo $line | cut -d' ' -f3`;
	echo "# command $cmd_sequence of $total_clusters, ($cluster cluster) ";
	echo "ssh -qt $server \"cd local/$dir/cnuapp/db/patches; PGUSER=postgres PGCLUSTER=$cluster ./apply_patch.pl $db $patch.sql\" ";
	echo " ";
	let "cmd_sequence+=1";
}

IFS='
';
	
echo "These are the commands YOU need to execute via copy/paste 1 at a time.

Patch subscribers first:
";

for line in `perl cnuapp_list.pl --pnl=$pnl --role=subscriber | sort -t' ' -rk2`
do
	make_cmds;
done;

line=`perl cnuapp_list.pl --pnl=$pnl --role=provider`;
echo " ";
echo "This is the provider to be patched last:";
make_cmds;

exit;
