BEGIN -- because need compile directives we have to do this with strings
EXECUTE IMMEDIATE q'[
CREATE OR REPLACE TYPE app_job_log_udt FORCE UNDER app_log_udt (
-- documentation at https://github.com/lee-lindley/plsql_utilities
    -- We are a subtype of app_log_udt. 
    -- We inherit attributes app_id, app_name
    -- and procedures log, log_p]'
$if $$use_html_email $then
||q'[
    caller_email        VARCHAR2(4000)
    ,
    --
    CONSTRUCTOR FUNCTION app_job_log_udt(
        p_job_name      VARCHAR2 -- will be converted to upper case and stored in app_name attribute
        ,p_email_to     VARCHAR2 DEFAULT NULL
    ) RETURN SELF AS RESULT]'
$else
||q'[
    --
    CONSTRUCTOR FUNCTION app_job_log_udt(
        p_job_name      VARCHAR2 -- will be converted to upper case and stored in app_name attribute
    ) RETURN SELF AS RESULT]'
$end
||q'[
    --
    -- call jstart (job start) at the start of your job, usually right after
    -- calling the constructuor. Puts a standard message in the log
    ,MEMBER PROCEDURE jstart(
        SELF IN OUT app_job_log_udt
        ,p_msg      VARCHAR2 DEFAULT NULL
    )
    -- call jdone (job done) upon successful completion of an entire job
    ,MEMBER PROCEDURE jdone(
        SELF IN OUT app_job_log_udt]'
$if $$use_html_email $then
||q'[
        -- optionally send an email message about job succses and perhaps additional instructions
        -- Puts a standard message in the log. p_msg does not go in the log - just in the email
        ,p_msg          VARCHAR2 DEFAULT NULL
        ,p_do_email     BOOLEAN DEFAULT FALSE]'
$end
||q'[
    )
    -- call jfailed just before the final raise of your error (or exit).
    -- puts a standard message in the log.
    -- puts all 3 non null CLOBS in the log.
    ,MEMBER PROCEDURE jfailed(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB DEFAULT NULL -- sqlerrm or anything else
        ,p_backtrace    CLOB DEFAULT NULL
        ,p_callstack    CLOB DEFAULT NULL]'
$if $$use_html_email $then
||q'[
        -- if do_email is TRUE, sends a failure email with the three clobs
        -- in HTML <CODE> blocks if not null.
        ,p_do_email     BOOLEAN DEFAULT FALSE]'
$end
||q'[
    )
    -- same as jfailed, but does not write 'FAILED job ' log message
    ,MEMBER PROCEDURE log_trace(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB DEFAULT NULL -- sqlerrm or anything else
        ,p_backtrace    CLOB DEFAULT NULL
        ,p_callstack    CLOB DEFAULT NULL]'
$if $$use_html_email $then
||q'[
        ,p_do_email     BOOLEAN DEFAULT FALSE
    )
    ,MEMBER PROCEDURE add_email_address(
        SELF IN OUT app_job_log_udt
        ,p_email_to     VARCHAR2
    )
    --
    -- if you want to send error email separate from jfailed, these will usually
    -- suffice. Still call jfailed, perhaps with no args.
    --
    ,MEMBER PROCEDURE email_error(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB
        ,p_do_log       BOOLEAN DEFAULT TRUE
    )
    ,MEMBER PROCEDURE email_error_bold(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB
        ,p_do_log       BOOLEAN DEFAULT TRUE
    )
    ,MEMBER PROCEDURE email_error_code(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB
        ,p_do_log       BOOLEAN DEFAULT TRUE
    )]'
$else
||' )'
$end
||q'[
    /*
        EXAMPLE:
            DECLARE
                g_log   app_job_log_udt;
            BEGIN
                g_log := app_job_log_udt(p_job_name);
                g_log.jstart
                ...

                g_log.log_p('inserted '||v_dest_file_name||' into gjrjflu as BLOB for user to retrieve from gjajflu screen');
                g_log.jdone(
                    p_msg => 'File '||v_dest_file_name||' is available for download from screen GJAJFLU under job name '||g_log.app_name||'.<br><p>Job completed with no errors.']'
$if $$use_html_email $then
||q'[

                    ,p_do_email => TRUE]'
$end
||q'[
                );
            EXCEPTION WHEN OTHERS THEN
                g_log.jfailed(
                    p_msg           => SQLERRM
                    ,p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                    ,p_callstack    => DBMS_UTILITY.FORMAT_CALL_STACK]'
$if $$use_html_email $then
||q'[

                    ,p_do_email     => TRUE]'
$end
||q'[
                );
                ROLLBACK;
                RAISE;
            END;
    */
) NOT FINAL
;
]'; -- end execute immediate
END; -- end anonymous block
/
show errors
