# app_job_log

An extension of logging for batch jobs.

- mark start and end of a batch job
- report errors in standardized format
- optionally send email on job failure and/or success

A subtype of [app_log_udt](#app_log), *app_job_log_udt* extends the logging facility
with methods suitable for marking the start and end of a batch job as well as
reporting errors. In particular the *jfailed* and *log_trace* methods simplify standardization
of a PL/SQL procedure EXCEPTION block. The standard message pattern for job startup and completion
logging makes it convenient to create analytic queries to analyze job history. Although your
job scheduling tool likely provides a way to do this, the database logs may give you greater
flexibility.

The type is optionally compiled with support for sending an email message for job failure
using [html_email](https://github.com/lee-lindley/html_email). Assuming you have already
installed *html_email*, see *app_job_log/install_app_job_log.sql*
for setting a compile directive to include it. Since *html_email* is dependent on *plsql_utilities*,
you may wind up recompiling it with the define set to 'TRUE' later.

The method interface for *app_job_log_udt* is (assuming use_html_email==TRUE):

```sql
    CONSTRUCTOR FUNCTION app_job_log_udt(
        p_job_name      VARCHAR2 -- will be converted to upper case and stored in app_name attribute
        ,p_email_to     VARCHAR2 DEFAULT NULL
    ) RETURN SELF AS RESULT
    --
    -- call jstart (job start) at the start of your job, usually right after
    -- calling the constructuor. Puts a standard message in the log
    ,MEMBER PROCEDURE jstart(
        SELF IN OUT app_job_log_udt
    )
    -- call jdone (job done) upon successful completion of an entire job
    ,MEMBER PROCEDURE jdone(
        SELF IN OUT app_job_log_udt
        -- optionally send an email message about job succses and perhaps additional instructions
        -- Puts a standard message in the log. p_msg does not go in the log - just in the email
        ,p_msg          VARCHAR2 DEFAULT NULL
        ,p_do_email     BOOLEAN DEFAULT FALSE
    )
    -- call jfailed just before the final raise of your error (or exit).
    -- puts a standard message in the log.
    -- puts all 3 non null CLOBS in the log.
    ,MEMBER PROCEDURE jfailed(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB DEFAULT NULL -- sqlerrm or anything else
        ,p_backtrace    CLOB DEFAULT NULL
        ,p_callstack    CLOB DEFAULT NULL
        -- if do_email is TRUE, sends a failure email with the three clobs
        -- in HTML <CODE> blocks if not null.
        ,p_do_email     BOOLEAN DEFAULT FALSE
    )
    -- same as jfailed, but does not write 'FAILED job ' log message
    ,MEMBER PROCEDURE log_trace(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB DEFAULT NULL -- sqlerrm or anything else
        ,p_backtrace    CLOB DEFAULT NULL
        ,p_callstack    CLOB DEFAULT NULL
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
    )
```

Example Usage:

```sql
    CREATE OR REPLACE PROCEDURE my_job_procedure 
    IS
        ...
        v_log   app_job_log := app_job_log('MY_DAILY_JOB', 'appsupport@mycompany.com');
    BEGIN
        v_log.jstart;
        ...
        v_log.log_p('start of long running dml'); 
        ...
        v_log.log_p('inserted '||TO_CHAR(SQL%ROWCOUNT)||' records into table whatever_table');
        COMMIT;
        ...
        v_log.jdone;
    EXCEPTION WHEN OTHERS THEN
        v_log.jfailed(
            p_msg           => SQLERRM
            ,p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            ,p_callstack    => DBMS_UTILITY.FORMAT_CALL_STACK
            ,p_do_email     => TRUE
        );
        ROLLBACK;
        RAISE;
    END my_job_procedure;
```

