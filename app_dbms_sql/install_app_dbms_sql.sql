whenever sqlerror continue
prompt OK for these to fail for type not exists
DROP TYPE app_dbms_sql_str_udt;
DROP TYPE app_dbms_sql_udt;
prompt OK if failed for type not exists
--whenever sqlerror exit failure
--
prompt beginning app_dbms_sql_udt.tps
@&&subdir/app_dbms_sql_udt.tps
prompt beginning app_dbms_sql_udt.tpb
@&&subdir/app_dbms_sql_udt.tpb
--
prompt beginning app_dbms_sql_str_udt.tps
@&&subdir/app_dbms_sql_str_udt.tps
prompt beginning app_dbms_sql_str_udt.tpb
@&&subdir/app_dbms_sql_str_udt.tpb
prompt deployment of app_dbms_sql_udt, app_dbms_sql_str_udt types is complete
prompt if the deployment reported that it could not drop or replace the types, then
prompt you may need to drop any dependent types first
