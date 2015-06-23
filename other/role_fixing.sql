\echo Please run this as the postgres user or cluster owner
\set ECHO all
/* 1. set variables */

/* USE THIS LIST:  https://git.zzzzz.com/gist/cwise/22b3524d1ca63170b6e9   FOR INITIAL VARIABLES TO SET HERE ... */

\set qwebrole '''':webrole''''
\set qownerrole '''':ownerrole''''
\set qdwrole '''':dwrole''''
\echo Implementing new owner role ( :qownerrole ) for migrations instead of app role ( :qwebrole ) in database :dbname
\echo Where old read role is :oldread, and reporting role is :reportrole. DW role is :dwrole

/* 2. connect to subject database and check search_path */
\c :dbname
SELECT (CASE WHEN array_to_string(s.setconfig,';') ~ 'search_path=:main_schema,' THEN true ELSE false END) AS path_is_correct
  FROM pg_database d
  LEFT OUTER JOIN pg_db_role_setting s ON d.oid=s.setdatabase
  WHERE d.datname = current_database()
;


/* 3. make postgres own the subject database in case it got changed somehow */
\c template1 postgres
ALTER DATABASE :dbname OWNER TO postgres;


/* 4. create the owner role if it doesn't exist, fix read role name */
CREATE ROLE :ownerrole;
ALTER ROLE :ownerrole WITH LOGIN NOSUPERUSER CREATEROLE CREATEDB;
GRANT CREATE ON DATABASE :dbname TO :ownerrole;
ALTER ROLE :ownerrole WITH PASSWORD '/* paste web role password here */' ; 

ALTER ROLE :oldread RENAME TO read_only;

/* 5. connect to subject database and start a transaction */
\c :dbname
SET statement_timeout=5000;
SET client_min_messages=DEBUG1;
BEGIN;

/*  create a temporary function that can process changes */
CREATE OR REPLACE FUNCTION reassign_objects (ownerrole VARCHAR, webrole VARCHAR, dwrole VARCHAR)
RETURNS INTEGER
LANGUAGE PLPGSQL
AS $$
DECLARE
  obj RECORD;
  sql TEXT := '';
BEGIN

/* find objects owned by web role that need permissions for web role to access after web role no longer owns them */
FOR obj IN
  SELECT c.oid::regclass::text AS relation
    , CASE WHEN has_table_privilege(webrole, c.oid, 'select') 
           THEN 'GRANT SELECT ON '|| c.oid::regclass::text ||' TO '|| webrole ||';' END AS _select
    , CASE WHEN has_table_privilege(webrole, c.oid, 'insert') AND c.relkind != 'S'
           THEN 'GRANT INSERT ON '|| c.oid::regclass::text ||' TO '|| webrole ||';' END AS _insert
    , CASE WHEN has_table_privilege(webrole, c.oid, 'update')
           THEN 'GRANT UPDATE ON '|| c.oid::regclass::text ||' TO '|| webrole ||';' END AS _update
    , CASE WHEN has_table_privilege(webrole, c.oid, 'delete') AND c.relkind != 'S'
           THEN 'GRANT DELETE ON '|| c.oid::regclass::text ||' TO '|| webrole ||';' END AS _delete
    , CASE WHEN c.relkind='S' THEN 
           CASE WHEN has_sequence_privilege(webrole, c.oid, 'usage') 
                THEN 'GRANT USAGE ON '|| c.oid::regclass::text ||' TO '|| webrole ||';' END ELSE NULL END AS _usage
    FROM pg_class c
    JOIN pg_roles r ON r.oid = c.relowner
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname NOT IN ('skytools','londiste','pgq','pgq_node','pgq_ext')
    WHERE c.relkind IN ('r', 'S', 'v')
    AND r.rolname = webrole
  LOOP
    IF obj._select IS NOT NULL THEN
      sql := sql || obj._select; 
    END IF;
    IF obj._insert IS NOT NULL THEN
      sql := sql || obj._insert; 
    END IF;
    IF obj._update IS NOT NULL THEN
      sql := sql || obj._update; 
    END IF;
    IF obj._delete IS NOT NULL THEN
      sql := sql || obj._delete; 
    END IF;
    IF obj._usage IS NOT NULL THEN
      sql := sql || obj._usage; 
    END IF;
  END LOOP;

/* find schemas and alter default privileges */
FOR obj IN
  SELECT n.nspname
    FROM pg_namespace n
    JOIN pg_roles r ON r.oid = n.nspowner
    WHERE r.rolname = webrole
    AND n.nspname NOT IN ('public','skytools','londiste','pgq','pgq_node','pgq_ext')
  LOOP
    sql := sql || 'GRANT USAGE ON SCHEMA '|| obj.nspname ||' TO '|| webrole ||';
            ALTER DEFAULT PRIVILEGES FOR ROLE '|| ownerrole ||' IN SCHEMA '|| obj.nspname ||'
              GRANT SELECT ON TABLES TO read_only;
            ALTER DEFAULT PRIVILEGES FOR ROLE '|| ownerrole ||' IN SCHEMA '|| obj.nspname ||' 
              GRANT INSERT, UPDATE, DELETE ON TABLES TO '|| webrole ||';
            ALTER DEFAULT PRIVILEGES FOR ROLE '|| ownerrole ||' IN SCHEMA '|| obj.nspname ||' 
              GRANT SELECT, USAGE ON SEQUENCES TO '|| webrole ||';';
  END LOOP;

/* find reporting schemas dw user */
FOR obj IN
  SELECT n.nspname
    FROM pg_namespace n
    JOIN pg_roles r ON r.oid = n.nspowner
    WHERE r.rolname = webrole
    AND n.nspname ~ 'reporting'
  LOOP
    sql := sql || 'GRANT USAGE ON SCHEMA '|| obj.nspname ||' TO '|| dwrole ||';
            ALTER DEFAULT PRIVILEGES FOR ROLE '|| ownerrole ||' IN SCHEMA '|| obj.nspname ||' 
              GRANT INSERT, UPDATE, DELETE ON TABLES TO '|| dwrole ||';
            ALTER DEFAULT PRIVILEGES FOR ROLE '|| ownerrole ||' IN SCHEMA '|| obj.nspname ||' 
              GRANT SELECT, USAGE ON SEQUENCES TO '|| dwrole ||';';
  END LOOP;

RAISE DEBUG 'moving objects to owner role [%] from web role [%]', ownerrole, webrole;
EXECUTE 'REASSIGN OWNED BY '|| webrole ||' TO '|| ownerrole;  -- does not work on types, so 'alter type' stmts in 1st loop

RAISE DEBUG 'all permissions [%]', sql;
EXECUTE sql;

RETURN 0;
end;
$$;

/* 6. execute function to move objects to new owner role */
SELECT reassign_objects (:qownerrole, :qwebrole, :qdwrole);

/* 7. remove high-level privileges from web role */
ALTER ROLE :webrole WITH NOSUPERUSER NOCREATEDB NOCREATEROLE;
REVOKE :ownerrole FROM :webrole;

/* 8. GRANT roles to roles */
GRANT read_only TO :webrole;
GRANT read_only TO :reportrole;
GRANT read_only TO :dwrole;
GRANT skytools TO :ownerrole;
GRANT read_only TO prodder__read_only;  -- if exists

/* 9. cleanup & commit */
DROP FUNCTION reassign_objects(VARCHAR, VARCHAR, VARCHAR);
COMMIT;

/* 10. londiste permissions, which is hopefully installed */
GRANT SELECT ON pgq_node.node_info, pgq_node.node_location TO :ownerrole;

/* 11. more role fixes only in reporting db, will error other places */
GRANT deployment TO :ownerrole;
REVOKE deployment FROM :webrole;


/* 12. verify ownership and permissions */
\echo this should return 0 rows
WITH r AS (SELECT oid FROM pg_roles WHERE rolname = :qwebrole)
SELECT pg_class.oid::regclass::text, relkind::text FROM pg_class JOIN r ON relowner = r.oid WHERE relkind IN ('S','v','r')
UNION ALL
SELECT proname, 'function' FROM pg_proc JOIN r ON proowner = r.oid
UNION ALL
SELECT nspname, 'schema' FROM pg_namespace JOIN r ON nspowner = r.oid
UNION ALL
SELECT typname, 'type' FROM pg_type JOIN r ON typowner = r.oid
ORDER BY 1
;

\c :dbname :ownerrole 
SELECT COUNT(0) FROM pgq_node.node_info;   -- should WORK
SELECT COUNT(0) FROM pgq_node.node_location;   -- should WORK
CREATE TABLE foo_role_test (id serial primary key, bar varchar(30)); -- should WORK
CREATE SCHEMA test_schema; -- should WORK

\c :dbname :webrole 
INSERT INTO foo_role_test (bar) VALUES ('oof');  -- should WORK 
UPDATE foo_role_test SET bar = 'yay' WHERE bar = 'oof';  -- should WORK 
SELECT * FROM foo_role_test;  -- should WORK
DELETE FROM foo_role_test;  -- should WORK
SELECT * FROM schema_migrations LIMIT 5;  -- should WORK
DROP TABLE foo_role_test;   -- should ERROR
ALTER TABLE foo_role_test ADD COLUMN nope BOOLEAN;  -- should ERROR

\c :dbname :ownerrole 
DROP TABLE foo_role_test;   -- should WORK
DROP SCHEMA test_schema;    -- should WORK


/* end */


/* read fixes: hopefully not needed outside of staging steps - because roles are shared in that one clus-aster */
SELECT nspname, 'ALTER DEFAULT PRIVILEGES FOR ROLE '|| :qownerrole ||' IN SCHEMA '|| nspname ||' GRANT SELECT ON TABLES TO read_only;     GRANT SELECT ON ALL TABLES IN SCHEMA '|| nspname ||' TO read_only;'
    FROM pg_namespace n
    JOIN pg_roles r ON r.oid = n.nspowner
    WHERE r.rolname = :qownerrole
    AND n.nspname NOT IN ('public', 'skytools', 'londiste','pgq','pgq_node','pgq_ext')
;
