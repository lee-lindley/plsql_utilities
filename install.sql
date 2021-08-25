set serveroutput on
--
-- You can pick and choose which of these to deploy. Dependencies are noted.
--
prompt arr_varchar2_udt.tps
@arr_varchar2_udt.tps
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
-- uncomment if you want app_dbms_sql. Generally it is compiled
-- by other repository install scripts that include plsql_utilities as a submodule
--define subdir=app_dbms_sql
--prompt calling &&subdir/install_app_dbms_sql.sql
--@&&subdir/install_app_dbms_sql.sql
