#!/bin/sh

BASEDIR=`dirname $0`

rm -f /tmp/dump1_parse.out
rm -f /tmp/dump2_parse.out

usage () {
cat << EOF
Generates a report of differences between schema dumps by object type

Usage:
$0 dump1 dump2 [option] 
 dump1: Should be the older or canonical source of schema dump
 dump2: Should be the newer or diverged schema dump

Options: ** Choose only 1 **
 -s  compare schema-related dump info 
 -t  compare table-related dump info (table definition) 
 -p  compare privilege/acl/permission-related dump info
 -i  compare index-related dump info
 -f  compare foreign key constraint-related dump info
 -c  compare constraint-related dump info for: primary keys, unique keys and checks
 -v  compare view-related dump info 
 -r  compare rule-related dump info
 -d  compare default column value-related dump info
 -g  compare trigger-related dump info
 -q  compare sequence-related dump info
 -x  compare function-related dump info 
 -m  compare comment-related dump info
 -y  compare type-related dump info 
 -n  compare domain-related dump info 
 -e  compare aggregate-related dump info
 -o  compare operator-related dump info
 -a  compare seed data
 -z  compare all schema objects listed above, except seed data (assumed when no options are passed in)
 -h  This help
EOF
exit
}

dump1=$1;
dump2=$2;
opt=$3;

case $opt in
      -s)
	      ;;
      -t)
	      ;;
      -p)
	      ;;
      -i)
	      ;;
      -f)
	      ;;
      -c)
	      ;;
      -v)
	      ;;
      -r)
	      ;;
      -d)
	      ;;
      -g)
	      ;;
      -q)
	      ;;
      -x)
	      ;;
      -m)
	      ;;
      -y)
	      ;;
      -n)
	      ;;
      -e)
	      ;;
      -o)
	      ;;
      -a)
	      ;;
      -z)
	      ;;
      -h)
        usage
        ;;
      -?)
        usage
        ;;
      "")
        ;;
      \?)
        echo "Invalid option. Use -h for help.";
	      exit;
        ;;
       *)
        echo "Invalid option: $opt. Use -h for help."
      	exit;
        ;;
    esac

if [ "$dump1" == "" ]
then
	echo "A Dump1 file is required. Use -h option for usage.";
	exit;
fi
if [ "$dump2" == "" ]
then
	echo "A Dump2 file is required. Use -h option for usage.";
	exit;
fi

if [ ! -r $dump1 ]
then
	echo "File $dump1 is not readable by this script. Please fix permissions or check existence of the file."
	exit;
fi

if [ ! -r $dump2 ]
then
	echo "File $dump2 is not readable by this script. Please fix permissions or check existence of the file."
	exit;
fi

rm -f /tmp/diff_dump1_dump2.out$opt

echo "Parsing of dump1 ($dump1) file ..." | tee /tmp/dump1_parse.out
cat $dump1 | ./parse_schema_dump.pl $opt >> /tmp/dump1_parse.out
echo "Parsing of dump2 ($dump2) file ..." | tee /tmp/dump2_parse.out
cat $dump2 | ./parse_schema_dump.pl $opt >> /tmp/dump2_parse.out

diff -uwibB /tmp/dump1_parse.out /tmp/dump2_parse.out > /tmp/diff_dump1_dump2.out$opt
echo "Unified diff output is in /tmp/diff_dump1_dump2.out$opt";

exit;

# vi: expandtab sw=2 ts=2
