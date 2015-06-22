#!/bin/bash

usage () {
cat << EOF
    Usage: `basename $0` tarfile_name [location_group]
    Pass in the name of the tar file to this script and it will scp/untar the tgz file to each server that is running a cnuapp db cluster.
    2nd parameter is optional to specify: 'snapshot' or one of the P&L codes.  Invalid options will result in not scp'ing any files anywhere.
EOF
    exit 1;
}

# 0) prerequisites: 
#	a) that you have already created the release patch and 
#	b) tarred the */db/* directory into a file named rYYYYMMDD.tgz and 
#	c) scp''ed to local/ on the server where this script is running
# 1) accept the tarfile name (for standard releases, it is the release date in YYYYMMDD format)
# 2) gets the distinct list of servers running cnuapp clusters and loops thru them
# 3) make the 'local' directory on the db server if it doesn''t exist
# 4) remove any previous copies of the directory with the name of the tarfile (happens frequently that you are all prepped with the release directory and they wedge in another patch or pull one out and you have to re-tar and start over)
# 5) scp''s the tar file to the server "local" directory
# following all done on the db server: 
# 6) makes the directory named after the tarfile for the release
# 7) cd''s to the release directory
# 8) untar''s the tar file in the release directory
# 9) cd''s to the patches directory
# 10) shows the end of the manifest.txt file (so you can see if you did in fact get the right tar file containing your new release patch)
# 11) run pg_lsclusters to show all clusters running there, just as an FYI
# 12) repeat from step 3 for each server

[[ $# -eq 0 ]] && usage ;

tarfile=`echo $1 | sed -e 's/\.tgz//'`;

if [ ! -f ~/local/$tarfile.tgz ]
then
	echo "ERROR: Cannot find the tarfile: ~/local/$tarfile.tgz";
	echo "Not able to continue.";
exit;
fi

if [ "$2" == "snapshot" ]
then
	location=" --role=snapshot";
else
	if [ "$2" == "" ]
	then
		location="";
	else
		location=" --pnl=$2";
	fi
fi

for line in `cnuapp_list.pl --servers_only $location`
do
 	server=$line;
	echo $server;
	ssh -q $server "mkdir -p local; cd local; rm -rf $tarfile*";
	scp -q ~/local/$tarfile.tgz $server:local/ ;
	ssh -q $server "mkdir local/$tarfile; cd local/$tarfile; tar xzf ~/local/$tarfile.tgz; cd cnuapp/db/patches; tail -4 manifest.txt; pg_lsclusters";
	echo " ";
done;
