#!/bin/bash

usage () {
cat << EOF
    Usage: `basename $0` pnl_code;
    Pass in the 'P&L' (us, jv, uk, ca, au) to this script of the Provider cluster on which to execute Londiste provider commands.
    Example:
    `basename $0` us

    Note: Script will display the list of tables/sequences that should be added to provider list
          user can type y to continue or n to exit
EOF
    exit 1;
}

schema_exception_list="'information_schema','londiste','pgq','garbage','txid','dbcheck','constraint_check','public','tools','code','code_internal','inheritance','replication','inheritance', 'analytics', 'object_monitor','import','setting','cabar','indexer','_indexer','adv_analytics','_genesys_analytics', 'genesys_transient', 'genesys_analytics', 'addresses'";

provider_tables_sql="
SELECT full_name
FROM  ( SELECT schemaname || '.' || tablename AS full_name
            FROM pg_tables
            WHERE schemaname NOT LIKE 'pg_%'
              AND NOT EXISTS( SELECT * FROM pg_roles WHERE rolname = schemaname )
              AND tableowner !~ 'orphaned_objects'
              AND schemaname!~ 'delete'
              AND schemaname NOT IN ( $schema_exception_list )
              AND schemaname NOT IN ( select nspname from pg_namespace where nspowner = (select oid from  pg_roles where rolname = 'orphaned_objects'))
              AND tablename NOT IN ('schema_patches','page_hits_queue')
              AND schemaname || '.' || tablename NOT IN ('cnu.brands_website_messages', 'cba.bad_time_sequence','genesys.us_campaign_records_stage','cnu.bright_tag_sessions','genesys.channel_messages','genesys.channel_messages_backup')
       ) t 
WHERE NOT EXISTS( SELECT * FROM londiste.table_info WHERE table_name = full_name)
"

provider_sequences_sql="
SELECT full_name
FROM  ( SELECT nspname || '.' || relname AS full_name
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relkind='S'
          AND nspname NOT LIKE 'pg_%'
          AND NOT EXISTS( SELECT * FROM pg_roles WHERE rolname = nspname )
          AND nspname!~ 'delete'
          AND nspowner NOT IN (select oid from  pg_roles where rolname = 'orphaned_objects')
          AND nspname NOT IN ( $schema_exception_list )
        ) s 
WHERE NOT EXISTS  ( SELECT * FROM londiste.seq_info WHERE seq_name = full_name )
"

RED_COLOR="$(tput setaf 1)"
GREEN_COLOR="$(tput setaf 2)"
NO_COLOR="$(tput sgr0)"

[[ $# -eq 0 ]] && usage ;

pnl=`echo $1 | tr '[A-Z]' '[a-z]'`;
londiste_queue="londiste.$pnl"

IFS='
';
for line in `cnuapp_list.pl --role=provider --pnl=$pnl`
do
  host_node=`echo "$line" | cut -d' ' -f1`
  echo "host: $host_node"

  cluster=`echo "$line" | cut -d' ' -f2`
  echo "cluster: $cluster"

  db=`echo "$line" | cut -d' ' -f3`
  echo "database: $db"

  provider_tables=`ssh -q $host_node "PGUSER=postgres PGCLUSTER="$cluster" psql --tuples-only --no-align --command=\"$provider_tables_sql\" $db"`
  retval=$?
  if [ "$retval" == "0" ] ; then
    echo -e "$RED_COLOR *** Provider Tables to be added: *** $NO_COLOR"
    echo -e "$provider_tables"
  else
    echo -e "$RED_COLOR *** couldnt get list of tables *** $NO_COLOR"
    exit $retval
  fi
  
  provider_sequences=`ssh -q $host_node "PGUSER=postgres PGCLUSTER="$cluster" psql --tuples-only --no-align --command=\"$provider_sequences_sql\" $db"`
  retval=$?
  if [ "$retval" == "0" ] ; then
    echo -e "$RED_COLOR *** Provider Sequences to be added: *** $NO_COLOR"
    echo -e "$provider_sequences"
  else
    echo -e "$RED_COLOR *** couldnt get list of Sequences *** $NO_COLOR"
    exit $retval
  fi
  
  if [ ! -z "$provider_tables" ] || [ ! -z "$provider_sequences" ] ; then
    read -p "Proceed with adding the above items as provider? y/n: "

    if [ "$REPLY" != "y" ]; then
      echo "Exiting per user request"
      exit 1
    fi

    if [ ! -z "$provider_tables" ] ; then
         for new_table in $provider_tables; do
            add_table_command="SET statement_timeout = 3000;SELECT londiste.local_add_table('$londiste_queue', '$new_table', '{}', NULL, NULL)"
            echo -e "Adding Table: $new_table"
            result=`ssh -q $host_node "PGUSER=postgres PGCLUSTER=\"$cluster\" psql --no-align --tuples-only --command=\"$add_table_command\" $db"`

          # 1 means success for tables  (200,"Table added: to_delete.st3_test") 
          if [[ "$result" == "(200,\"Table added: "* ]]; then
            echo -e "$GREEN_COLOR Added table: $new_table :: $result $NO_COLOR"
          else
            echo -e "$RED_COLOR ERROR: $result $NO_COLOR"
          fi
        done
    fi

    if [ ! -z "$provider_sequences" ] ; then
      for new_seq in $provider_sequences; do
        add_seq_command="SET statement_timeout = 3000;SELECT londiste.local_add_seq('$londiste_queue','$new_seq')"
        echo -e "Adding Sequence: $new_seq"
        result=`ssh -q $host_node "PGUSER=postgres PGCLUSTER=\"$cluster\" psql --no-align --tuples-only --command=\"$add_seq_command\" $db"`

        # 0 means success for sequences (200,"Sequence added: to_delete.st3_test_id_seq")
        if [[ "$result" == "(200,\"Sequence added: "* ]]; then
          echo -e "$GREEN_COLOR Added Sequence: $new_seq :: $result $NO_COLOR"
        else
          echo -e "$RED_COLOR ERROR: $result $NO_COLOR"
        fi
      done
    fi

  else
    echo -e "$GREEN_COLOR No tables/sequences needed to be added: $new_table $NO_COLOR"
    exit 0
  fi

done
