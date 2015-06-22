#!/bin/bash

# This script takes a path parameter that is where the patch or manifest.txt exists that contains the patches to be released (or put into a release patch
# It pulls patches out of the file and builds a search command for Acunote
# It searches for the reviews for the tasks listed in the patches.
# The command output must be pasted into a browser.
# TODO: make it hit the Acunote database somehow to do the lookups of approvals

usage () {
cat << EOF
    Usage: `basename $0` path [patch_name]
    Pass in the path to the manifest/patch containing patch candidates for release.
    It pulls patches out of the file and builds a search command for Acunote.
    Example usage:
      ./`basename $0` /Users/superdev/git/cnuapp/db/patches 
EOF
    exit 1;
}

[[ $# -eq 0 ]] && usage ;

path=$1
if [ "$2" == "" ]
then
  file="manifest.txt"
else
  file=$2
fi

search_command="https://acunote.cashnetusa.com/tasks?query=review+AND+%28";
append="";
echo "Building search command for tasks:";
for patch in `grep 'bug_[1-9]' $path/$file | grep -vi release | sed -e 's/-- patchdeps: //'`
do
  task_number=`echo $patch | cut -d'_' -f2 | grep '[0-9]'`;
  if [ "$task_number" != "" ]
  then
    echo "  $task_number (patch $patch)";
    search_command=$search_command$append$task_number;
    append="+OR+";
  fi
done
search_command=$search_command"%29";
echo "";
echo "Paste this command into your browser url line:
$search_command";
echo "";
exit;
