--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
--define char_collection_type="arr_varchar2_udt"
whenever sqlerror exit failure
prompt calling japh_util_udt.tps
@@japh_util_udt.tps
prompt calling japh_util_udt.tpb
@@japh_util_udt.tpb
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
GRANT EXECUTE ON japh_util_udt TO PUBLIC;