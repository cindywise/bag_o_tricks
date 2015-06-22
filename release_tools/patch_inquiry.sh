#!/bin/bash

usage () {
cat << EOF
	Usage: `basename $0` patch_name [p_and_l_code]
	Pass in a patch name to query tools.schema_patches in all the production clusters.
	If no P&L code is passed in, then all standard cnuapp clusters are queried.
EOF
}

# This script uses the cluster file read in the cnuapp_list.pl script to find all the production cnuapp servers, clusters and databases.
# Utilize this script while verifying patchdeps while building the release patch. A patchdep of a releasing patch candidate must be either already applied or have been reviewed/approved the same as the patch itself. 

patch=$1;
pnl=`echo $2 | sed -e 's/\.//'`;

shift;

if [ -z "$patch" ]; then
	usage
	exit 0
fi

if [ "$pnl" ]; then
	pnl="--pnl=$pnl";
fi

cmd="SELECT applied_at FROM tools.schema_patches WHERE patch_file = '$patch'";

IFS='
';
for line in `perl cnuapp_list.pl $pnl | sort -t'/' -k2`
do
	db=`echo $line | cut -d' ' -f3`;
	server=`echo $line | cut -d' ' -f1`;
	cluster=`echo $line | cut -d' ' -f2`;
	echo -n "$cluster cluster on $server server: ";
	ssh -q $server "PGUSER=postgres PGCLUSTER=$cluster psql $db --tuples-only --command \"$cmd \" ";
done;

