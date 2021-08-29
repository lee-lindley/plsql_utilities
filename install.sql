set serveroutput on
--
-- You can pick and choose which of these to deploy. Dependencies are noted.
--
prompt arr_clob_udt.tps
@app_types/arr_clob_udt.tps
prompt arr_arr_clob_udt.tps
@app_types/arr_arr_clob_udt.tps
prompt arr_varchar2_udt.tps
@app_types/arr_varchar2_udt.tps
--
-- split requires arr_varchar2_udt or you can edit it to use your own version
prompt split.sql
@split.sql
--
define subdir=app_log
prompt calling &&subdir/install_app_log.sql
@&&subdir/install_app_log.sql
--
define subdir=app_parameter
prompt &&subdir/install_app_parameter.sql
@&&subdir/install_app_parameter.sql
--
prompt to_zoned_decimal.sql
@to_zoned_decimal.sql
--
define subdir=app_lob
prompt calling &&subdir/install_app_lob.sql
@&&subdir/install_app_lob.sql
--
define subdir=as_zip
prompt calling &&subdir/install_as_zip.sql
@&&subdir/install_as_zip.sql
--
-- requires as_zip, split, app_lob and arr_varchar2_udt(or equivalent you substitute in the source files)
define subdir=app_zip
prompt calling &&subdir/install_app_zip.sql
@&&subdir/install_app_zip.sql
--
 /*
 uncomment if you want app_dbms_sql. Generally it is compiled
 by other repository install scripts that include plsql_utilities as a submodule
 requires arr_clob_udt, arr_arr_clob_udt, and arr_varchar2_udt
*/
--define subdir=app_dbms_sql
--prompt calling &&subdir/install_app_dbms_sql.sql
--@&&subdir/install_app_dbms_sql.sql
--
prompt running compile_schema for invalid objects
BEGIN
    DBMS_UTILITY.compile_schema( schema => SYS_CONTEXT('userenv','current_schema')
                                ,compile_all => FALSE
                                ,reuse_settings => TRUE
                            );
END;
/
