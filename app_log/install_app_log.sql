--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
whenever sqlerror continue
prompt must drop objects using app_log_udt as supertype
DROP TYPE app_job_log_udt FORCE;
prompt ok drop failed for type not exists
--
DROP TYPE app_log_udt FORCE;
prompt ok drop failed for type not exists
DROP VIEW app_log_v;
prompt ok if drop failed for view not exists
DROP VIEW app_log_base_v;
prompt ok if drop failed for view not exists
DROP VIEW app_log_tail_v;
prompt ok if drop failed for view not exists
--
DROP TABLE app_log_1;
DROP TABLE app_log_2;
prompt ok if drop fails for table not exists
DROP TABLE app_log_app;
prompt ok if drop fails for table not exists
DROP SEQUENCE app_log_app_seq;
prompt ok if drop fails for sequence not exists
--
whenever sqlerror exit failure
prompt calling app_log_app.sql
@@app_log_app.sql
prompt calling app_log.sql to create tables
@@app_log.sql
prompt calling app_log_views.sql
@@app_log_views.sql
prompt calling app_log_udt.tps
@@app_log_udt.tps
prompt calling app_log_udt.tpb
@@app_log_udt.tpb
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
--
-- put a record into the log for funzies
DECLARE
    v_logger app_log_udt := app_log_udt('app_log');
BEGIN
    v_logger.log('This will be the first message in the log after code deploy from app_log.sql');
END;
/
--GRANT EXECUTE ON app_log_udt TO ???; -- trusted application schemas only. Not people
-- select can be granted to roles and people who are trusted to see log messages.
-- that depends on what you are putting in the log messages. Hopefully no secrets.
--GRANT SELECT ON app_log_1 TO ???; 
--GRANT SELECT ON app_log_2 TO ???; 
--GRANT SELECT ON app_log_app TO ???; 
--GRANT SELECT ON app_log_v TO ???; 
--GRANT SELECT ON app_log_tail_v TO ???; 
--GRANT SELECT ON app_log_base_v TO ???;
