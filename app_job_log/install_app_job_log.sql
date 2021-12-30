--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
whenever sqlerror exit failure
set serveroutput on
set define on
define use_html_email="FALSE"
ALTER SESSION SET PLSQL_CCFLAGS='use_html_email:&&use_html_email.';
prompt calling app_job_log_udt.tps
@@app_job_log_udt.tps
prompt calling app_job_log_udt.tpb
@@app_job_log_udt.tpb
ALTER SESSION SET PLSQL_CCFLAGS='';
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
--
-- put records into the log for funzies
DECLARE
    v_logger app_job_log_udt := app_job_log_udt('app_job_log');
BEGIN
    v_logger.jstart;
    v_logger.jdone;
    v_logger.jfailed(
        p_msg   => SQLERRM
        ,p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        ,p_callstack    => DBMS_UTILITY.FORMAT_CALL_STACK
    );
END;
/
prompt ignore that 'FAILED job APP_JOB_LOG' message. That is just the install validation of logger.
--GRANT EXECUTE ON app_job_log_udt TO ???; -- trusted application schemas only. Not people
