#!/bin/bash

# This script takes a release date and outputs wiki code to start the itemization page.
# This is not offcycle-capable, as those are usually a single patch and standard releases involve multiple patches to document.
# It pulls patches out of the release patch and creates some basic wiki code to save some of the repititive manual work involved.
# TODO: make it create smarter wiki code and create the wiki page automagically

usage () {
cat << EOF
    Usage: `basename $0` path_to_release_patch yyyymmdd
    Pass in the release date of the patch that needs to be itemized in the wiki:
      https://acunote.cashnetusa.com/projects/5237/wiki/DB_Release_Patch_Itemization
    Example usage:
      ./`basename $0` cnuapp/db/patches 20140102
EOF
    exit 1;
}

[[ $# -eq 0 ]] && usage ;

path=$1/../../../*/db/patches;
yyyymmdd=$2;
release_patch="release_${yyyymmdd:0:4}-${yyyymmdd:4:2}-${yyyymmdd:6:2}";
IFS='
';
echo "Copy and paste these into the wiki, then edit and fill extra details as needed:";
echo "= [https://git.......com/cnuapp/cnuapp/tree/r$yyyymmdd/cnuapp/db/patches/$release_patch.sql $release_patch] =
";

for individual_patch in `grep -i '\-\- patchdeps: ' $path/$release_patch.sql | sed -e 's/\-\- patchdeps: //' -e 's/ /\\n/g'` 
do
   echo "== [https://git.......com/cnuapp/cnuapp/tree/r$yyyymmdd/cnuapp/db/patches/$individual_patch.sql $individual_patch] =="; 
  for statement in `grep -iE "create |insert into |alter |add column |drop " $path/$individual_patch.sql | cut -d'(' -f1`
  do
    echo "* $statement";
  done;
  for statement in `grep -iE "\.setting|backfill|indexer|update |delete from |truncate |\\i \.\.|code_internal|tools\.assert" $path/$individual_patch.sql`
  do
    echo "* $statement";
  done;
  echo "";
done;
exit;
