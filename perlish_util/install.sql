--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
define d_arr_varchar2_udt="arr_varchar2_udt"
define d_arr_arr_varchar2_udt="arr_arr_varchar2_udt"
@@install_perlish_util_spec.sql
----- this assumes app_csv_pkg spec has been declared
@@install_perlish_util_body.sql
