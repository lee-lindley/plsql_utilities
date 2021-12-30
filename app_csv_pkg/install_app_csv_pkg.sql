--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
whenever sqlerror exit failure
prompt calling app_csv_pkg.pks
@@app_csv_pkg.pks
prompt calling app_csv_pkg.pkb
@@app_csv_pkg.pkb
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
GRANT EXECUTE ON app_csv_pkg TO PUBLIC;
