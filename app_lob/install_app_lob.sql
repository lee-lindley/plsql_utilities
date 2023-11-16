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
--
prompt beginning app_lob.pks
@@app_lob.pks
prompt beginning app_lob.pkb
@@app_lob.pkb
prompt deployment of app_lob package is complete
