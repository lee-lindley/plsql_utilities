set serveroutput on
ALTER SESSION SET PLSQL_CCFLAGS='use_app_log:TRUE,use_app_parameter:TRUE,use_mime_type:TRUE,use_split:TRUE';
--
prompt arr_varchar2_udt.tps
@arr_varchar2_udt.tps
--
define subdir=app_log
prompt calling &&subdir/install_app_log.sql
@&&subdir/install_app_log.sql
--
prompt split.sql
@split.sql
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
define subdir=html_email_udt
prompt calling &&subdir/install_html_email_udt.sql
-- set these appropriately for html_email_udt
define from_email_addr="donotreply@bogus.com"
define reply_to="donotreply@bogus.com"
define smtp_server="localhost"
--
@&&subdir/install_html_email_udt.sql
