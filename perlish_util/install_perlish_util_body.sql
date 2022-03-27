--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
--define d_arr_varchar2_udt="arr_varchar2_udt"
whenever sqlerror exit failure
prompt calling perlish_util_udt.tpb
@@perlish_util_udt.tpb
--
prompt calling perlish_util_pkg.pkb
@@perlish_util_pkg.pkb
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
--GRANT EXECUTE ON perlish_util_udt TO PUBLIC;
--GRANT EXECUTE ON arr_perlish_util_udt TO PUBLIC;
--GRANT EXECUTE ON perlish_util_pkg TO PUBLIC;
