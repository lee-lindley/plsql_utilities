set serveroutput on
ALTER SESSION SET PLSQL_CCFLAGS='use_app_log:TRUE,use_app_parameter:TRUE,use_mime_type:TRUE,use_split:TRUE';
@arr_varchar2_udt.sql
@app_log.sql
@split.sql
@app_parameter.sql
@to_zoned_decimal.sql
@app_lob.sql
@html_email_udt.sql
