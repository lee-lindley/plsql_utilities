--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
whenever sqlerror exit failure
prompt calling csv_to_table_pkg.pks
@@csv_to_table_pkg.pks
prompt calling csv_to_table_pkg.pkb
@@csv_to_table_pkg.pkb
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
--GRANT EXECUTE ON csv_to_table_pkg TO PUBLIC;
