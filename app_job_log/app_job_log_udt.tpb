CREATE OR REPLACE TYPE BODY app_job_log_udt IS
    -- we are a subtype of app_log_udt. We inherit attributes app_id, app_name
    -- and procedures log, log_p

    CONSTRUCTOR FUNCTION app_job_log_udt(
        p_job_name      VARCHAR2
$if $$use_html_email $then
        ,p_email_to     VARCHAR2 DEFAULT NULL
$end
    ) RETURN SELF AS RESULT
    IS
    BEGIN
        -- call superclass procedure to take care of details
        SELF.app_log_udt_constructor(p_job_name);
$if $$use_html_email $then
        caller_email := p_email_to;
$end
        RETURN;
    END;

$if $$use_html_email $then
    MEMBER PROCEDURE add_email_address(
        SELF IN OUT app_job_log_udt
        ,p_email_to         VARCHAR2
    ) IS
    BEGIN
        IF p_email_to IS NOT NULL THEN
            caller_email := CASE WHEN caller_email IS NULL THEN p_email_to ELSE caller_email||','||p_email_to END;
        END IF;
    END;

    MEMBER PROCEDURE email_error(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB
        ,p_do_log       BOOLEAN DEFAULT TRUE
    ) IS
    BEGIN
        IF p_do_log THEN
            SELF.log_p(p_msg);
        END IF;
        IF caller_email IS NOT NULL THEN
            html_email_udt(
                p_log       => SELF
                ,p_to_list  => caller_email
                ,p_subject  => 'Job '||app_name||' failed'
                ,p_body     => '<p>Job '||app_name||' failed with error message:<br>
<br>'||p_msg
            ).send;
        END IF;
    END;
    MEMBER PROCEDURE email_error_bold(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB
        ,p_do_log       BOOLEAN DEFAULT TRUE
    ) IS
    BEGIN
        email_error('<p><b>'||p_msg||'</b>');
    END;

    MEMBER PROCEDURE email_error_code(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB
        ,p_do_log       BOOLEAN DEFAULT TRUE
    ) IS
    BEGIN
        email_error('<pre><code>'||p_msg||'</code></pre>');
    END;
$end

    MEMBER PROCEDURE jstart(
        SELF IN OUT app_job_log_udt
    )
    IS
    BEGIN
        SELF.log_p('START job '||app_name);
    END;

    MEMBER PROCEDURE jfailed(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB DEFAULT NULL -- sqlerrm or anything else
        ,p_backtrace    CLOB DEFAULT NULL
        ,p_callstack    CLOB DEFAULT NULL
$if $$use_html_email $then
        ,p_do_email     BOOLEAN DEFAULT FALSE
$end
    ) IS
    BEGIN
        IF p_msg IS NOT NULL OR p_backtrace IS NOT NULL OR p_callstack IS NOT NULL 
$if $$use_html_email $then
            OR p_do_email 
            THEN log_trace(p_msg, p_backtrace, p_callstack, p_do_email);
$else
            THEN log_trace(p_msg, p_backtrace, p_callstack);
$end
        END IF;
        SELF.log_p('FAILED job '||app_name);
    END;

    MEMBER PROCEDURE log_trace(
        SELF IN OUT app_job_log_udt
        ,p_msg          CLOB DEFAULT NULL -- sqlerrm or anything else
        ,p_backtrace    CLOB DEFAULT NULL
        ,p_callstack    CLOB DEFAULT NULL
$if $$use_html_email $then
        ,p_do_email     BOOLEAN DEFAULT FALSE
$end
    ) IS
    BEGIN
$if $$use_html_email $then
        IF p_do_email AND caller_email IS NOT NULL THEN
            DECLARE
                v_email         html_email_udt;
            BEGIN
                v_email := html_email_udt(
                    p_log       => SELF
                    ,p_to_list  => caller_email
                    ,p_subject  => 'Job '||app_name||' failed'
                    ,p_body     => '<p>Job '||app_name||' failed with error message:<br>'
                );
                IF p_msg IS NULL AND p_backtrace IS NULL AND p_callstack IS NULL THEN
                    v_email.add_paragraph('No error message provided.');
                END IF;
                IF p_msg IS NOT NULL THEN
                    v_email.add_paragraph('Error Message:');
                    v_email.add_code_block(p_msg);
                END IF;
                IF p_backtrace IS NOT NULL THEN
                    v_email.add_paragraph('Error BackTrace:');
                    v_email.add_code_block(p_backtrace);
                END IF;
                IF p_callstack IS NOT NULL THEN
                    v_email.add_paragraph('Call Stack:');
                    v_email.add_code_block(p_callstack);
                END IF;
                v_email.send;
            END;
        END IF;
$end
        IF p_msg IS NOT NULL THEN
            SELF.log_p(p_msg);
        END IF;
        IF p_backtrace IS NOT NULL THEN
            SELF.log_p('backtrace: '||p_backtrace);
        END IF;
        IF p_callstack IS NOT NULL THEN
            SELF.log_p('callstack: '||p_callstack);
        END IF;
    END;

    MEMBER PROCEDURE jdone(
        SELF IN OUT app_job_log_udt
$if $$use_html_email $then
        ,p_msg          VARCHAR2 DEFAULT NULL
        ,p_do_email     BOOLEAN DEFAULT FALSE
$end
    ) IS
    BEGIN
$if $$use_html_email $then
        IF p_do_email AND caller_email IS NOT NULL THEN
            html_email_udt(
                p_log       => SELF
                ,p_to_list  => caller_email
                ,p_subject  => 'Job '||app_name||' complete'
                ,p_body     => '<p>'||NVL(p_msg, 'Job '||app_name||' completed with no errors')
            ).send;
        END IF;
$end
        SELF.log_p('DONE job '||app_name);
    END;

END;
/
show errors
