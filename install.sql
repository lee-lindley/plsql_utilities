spool install.log
set serveroutput on
--
-- for conditional compilation based on sqlplus define settings.
-- When we select a column alias named "file_choice", we get a sqlplus define value for "file_choice"
--
COLUMN file_choice NEW_VALUE do_file NOPRINT
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
-- Set these to FALSE if you do not need to compile them
define compile_arr_integer_udt="TRUE"
define compile_arr_varchar2_udt="TRUE"
define compile_arr_arr_varchar2_udt="TRUE"
define compile_arr_clob_udt="TRUE"
define compile_arr_arr_clob_udt="TRUE"
define compile_app_dbms_sql="FALSE"

define subdir=app_types
SELECT DECODE('&&compile_arr_integer_udt','TRUE','&&subdir./arr_integer_udt.tps', 'do_nothing.sql arr_integer_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
SELECT DECODE('&&compile_arr_varchar2_udt','TRUE','&&subdir./arr_varchar2_udt.tps', 'do_nothing.sql arr_varchar2_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
SELECT DECODE('&&compile_arr_arr_varchar2_udt','TRUE','&&subdir./arr_arr_varchar2_udt.tps', 'do_nothing.sql arr_arr_varchar2_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
SELECT DECODE('&&compile_arr_clob_udt','TRUE','&&subdir./arr_clob_udt.tps', 'do_nothing.sql arr_clob_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
SELECT DECODE('&&compile_arr_arr_clob_udt','TRUE','&&subdir./arr_arr_clob_udt.tps', 'do_nothing.sql arr_arr_clob_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
--
define subdir=app_lob
prompt calling &&subdir/install_app_lob.sql
@&&subdir/install_app_lob.sql
--
-- perlish_util_udt and app_csv_pkg require arr_varchar2_udt or your version of same.
-- The two are mutually dependent so we compile specs first then bodies
--
define subdir=perlish_util
prompt calling &&subdir/install_perlish_util_spec.sql
@@&&subdir/install_perlish_util_spec.sql
define subdir=app_csv_pkg
prompt calling &&subdir/install_app_csv_pkg_spec.sql
@@&&subdir/install_app_csv_pkg_spec.sql
prompt calling &&subdir/install_app_csv_pkg_body.sql
@@&&subdir/install_app_csv_pkg_body.sql
define subdir=perlish_util
prompt calling &&subdir/install_perlish_util_body.sql
@@&&subdir/install_perlish_util_body.sql
--
define subdir=app_log
prompt calling &&subdir/install_app_log.sql
@@&&subdir/install_app_log.sql
-- see define use_html_email in install_app_job_log.sql
define subdir=app_job_log
prompt calling &&subdir/install_app_job_log.sql
@@&&subdir/install_app_job_log.sql
--
define subdir=app_parameter
prompt &&subdir/install_app_parameter.sql
@@&&subdir/install_app_parameter.sql
--
define subdir=misc
prompt &&subdir/to_zoned_decimal.pls
@@&&subdir/to_zoned_decimal.pls
--
define subdir=as_zip
prompt calling &&subdir/install_as_zip.sql
@@&&subdir/install_as_zip.sql
--
-- requires as_zip, app_csv_pkg (for split_csv), app_lob 
-- and arr_varchar2_udt 
--
define subdir=app_zip
prompt calling &&subdir/install_app_zip.sql
@@&&subdir/install_app_zip.sql
--
-- requires arr_clob_udt, arr_arr_clob_udt, arr_integer_udt, and arr_varchar2_udt
define subdir=app_dbms_sql 
SELECT DECODE('&&compile_app_dbms_sql','TRUE','&&subdir./install_app_dbms_sql.sql', 'do_nothing.sql app_dbms_sql') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
--
--prompt running compile_schema for invalid objects
--BEGIN
--    DBMS_UTILITY.compile_schema( schema => SYS_CONTEXT('userenv','current_schema')
--                                ,compile_all => FALSE
--                                ,reuse_settings => TRUE
--                            );
--END;
--/
spool off
