set serveroutput on
-- set to FALSE if you do not want app_lob to use the application logging facilities.
-- If you set it to false, you do not need to run install_app_log.
--
-- You can pick and choose which of these to deploy. Dependencies are noted.
--
define use_app_log="TRUE"
ALTER SESSION SET PLSQL_CCFLAGS='use_app_log:&&use_app_log.';
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
-- depends on install_app_log.sql unless the compile directive at the top of install.sql is set to FALSE
define subdir=app_lob
prompt calling &&subdir/install_app_lob.sql
@&&subdir/install_app_lob.sql
