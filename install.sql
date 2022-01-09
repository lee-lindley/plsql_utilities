set serveroutput on
--
-- People care about naming conventions. You must define these collection type names.
-- If you already have collection types named the way you like, define those names here
-- and comment out the install of the corresponding type in the app_types/install_app_types.sql script
--
define d_arr_integer_udt="arr_integer_udt"
define d_arr_varchar2_udt="arr_varchar2_udt"
define d_arr_arr_varchar2_udt="arr_arr_varchar2_udt"
define d_arr_clob_udt="arr_clob_udt"
define d_arr_arr_clob_udt="arr_arr_clob_udt"
-- Here are some alternative names that may suit
--define d_arr_integer_udt="integer_tab_t"
--define d_arr_varchar2_udt="varchar2_tab_t"
--define d_arr_arr_varchar2_udt="varchar2_tab_tab_t"
--define d_arr_clob_udt="clob_tab_t"
--define d_arr_arr_clob_udt="clob_tab_tab_t"
--
prompt app_types/install_app_types.sql
@@app_types/install_app_types.sql
--
-- japh_util_udt requires arr_varchar2_udt or your version of same
--
define char_collection_type="arr_varchar2_udt"
--
define subdir=japh_util
prompt calling &&subdir/install_japh_util.sql
@&&subdir/install_japh_util.sql
--
-- csv_to_table_pkg requires arr_varchar2_udt or you can use your own version
-- setting define char_collection_type
--
define subdir=csv_to_table 
prompt calling &&subdir/install_csv_to_table.sql
@&&subdir/install_csv_to_table.sql
--
define subdir=app_csv_pkg
prompt calling &&subdir/install_app_csv_pkg.sql
@&&subdir/install_app_csv_pkg.sql
--
define subdir=app_log
prompt calling &&subdir/install_app_log.sql
@&&subdir/install_app_log.sql
-- see define use_html_email in install_app_job_log.sql
define subdir=app_job_log
prompt calling &&subdir/install_app_job_log.sql
@&&subdir/install_app_job_log.sql
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
-- requires as_zip, japh_util_udt (for split_csv), app_lob 
-- and arr_varchar2_udt 
--
define subdir=app_zip
prompt calling &&subdir/install_app_zip.sql
@&&subdir/install_app_zip.sql
--
 /*
 uncomment if you want app_dbms_sql. Generally it is compiled
 by other repository install scripts that include plsql_utilities as a submodule
 requires arr_clob_udt, arr_arr_clob_udt, arr_integer_udt, and arr_varchar2_udt
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
