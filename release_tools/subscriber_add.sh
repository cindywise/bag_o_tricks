#!/bin/bash

#todo> add logic to bypass the y/n question if nothing to do######

usage () {
cat << EOF
    Usage: `basename $0` p_and_l__code
    Pass in the 'P&L' (us, jv, uk, ca, au) to process.
    Example:
    `basename $0` uk

    Note: Script will display the list of tables/sequences that should be added to Subscriber list.
          The user can enter "y" to continue or "n" to exit.
EOF
    exit 1;
}

pnl=`echo $1 | tr '[A-Z]' '[a-z]'`;
[[ $# -eq 0 ]] && usage ;

BOLD_FONT="$(tput bold)";
RED_COLOR="${BOLD_FONT}$(tput setaf 1)";
GREEN_COLOR="${BOLD_FONT}$(tput setaf 2)";
NO_COLOR="$(tput sgr0)";

londiste_queue="londiste.$pnl";
finding_sql="SELECT obj_name FROM londiste.local_show_missing('$londiste_queue')";
finding_tables="$finding_sql WHERE obj_kind = 'r' ORDER BY obj_name\" ";
finding_sequences="$finding_sql WHERE obj_kind = 'S' ORDER BY obj_name\" ";

function find_them {
  missing_list=`ssh -q $host_node "$psql_exec $finding_items"`;
  retval=$?;
  if [ "$retval" == "0" ] ; then
    if [ ! -z "$missing_list" ] ; then
    	echo -e "$RED_COLOR	*** Subscriber $item_types to be added: *** $NO_COLOR";
    	echo -e "$missing_list" | sed -e 's/^/		/';
    fi
  else
    echo -e "$RED_COLOR	*** Unable to get list of $item_types. *** $NO_COLOR";
    exit $retval;
  fi
}

function subscribe_them {
  for new_item in $subscriber_list; 
  do
    add_command="SET statement_timeout = 3000;SELECT $londiste_add_function ('$londiste_queue'::text, '$new_item'::text )\" ";
    echo -e "	Attempting to Subscribe $item_type: $new_item";
    result=`ssh -q $host_node "$psql_exec $add_command"`;
    if [[ "$result" == "(200,\"$item_type added: "* ]]; then
       echo -e "$GREEN_COLOR		Added $item_type: $new_item :: $result $NO_COLOR";
    else
       echo -e "$RED_COLOR ERROR: $result $NO_COLOR";
    fi
  done;
}

IFS='
';
for line in `perl cnuapp_list.pl --role=subscriber --pnl=$pnl | sort -k2`;
do
  host_node=`echo "$line" | cut -d' ' -f1`;
  cluster=`echo "$line" | cut -d' ' -f2`;
  db=`echo "$line" | cut -d' ' -f3`;
  echo " ";
  echo -e "$BOLD_FONT Cluster: $cluster, Database: $db, Host: $host_node";

  # load part of the psql execution line, the rest of the psql command is set in the logic below
  psql_exec="PGCLUSTER="$cluster" psql $db --tuples-only --no-align --command=\"SET ROLE su; ";

  finding_items=$finding_tables;
  item_types="Tables";
  find_them;
  subscriber_tables=$missing_list;
  
  finding_items=$finding_sequences;
  item_types="Sequences";
  find_them;
  subscriber_sequences=$missing_list;
  
  if [ ! -z "$subscriber_tables" ] || [ ! -z "$subscriber_sequences" ] ; then
    read -p "$GREEN_COLOR	Proceed with individually Subscribing the above items? y/n: $NO_COLOR";

    if [ "$REPLY" != "y" ]; then
      echo "	Skipping cluster ($cluster) per user request.";
      continue;
    fi

    if [ ! -z "$subscriber_tables" ] ; then
	subscriber_list=$subscriber_tables;
	londiste_add_function="londiste.local_add_table";
        item_type="Table";
	subscribe_them;
    fi

    if [ ! -z "$subscriber_sequences" ]; then
	subscriber_list=$subscriber_sequences;
	londiste_add_function="londiste.local_add_seq";
        item_type="Sequence";
	subscribe_them;
    fi

  else
    echo -e "$GREEN_COLOR	No tables/sequences need to be subscribed on this cluster ($cluster). $NO_COLOR";
  fi

done;

echo -e " ";
echo -e "Finished. Please run londiste_provider_status.sh to confirm objects count from Subscribers match the Provider.";
exit;
