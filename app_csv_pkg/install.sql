define d_arr_varchar2_udt="arr_varchar2_udt"
define d_arr_arr_varchar2_udt="arr_arr_varchar2_udt"
whenever sqlerror exit failure
COLUMN :cs NEW_VALUE cs NOPRINT
VARIABLE cs VARCHAR2(128)
BEGIN
    :cs := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
END;
/
SELECT :cs FROM dual;
define compile_schema=&&cs;
rem
prompt calling app_csv_pkg.pks
@@app_csv_pkg.pks
prompt calling app_csv_pkg.pkb
@@app_csv_pkg.pkb
