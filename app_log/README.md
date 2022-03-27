# app_log

A lightweight and fast general purpose database application logging facility, 
the core is an object oriented user defined type with methods for writing 
time-stamped log records to a table.  Since the autonomous transactions write independently,
you can get status of the program before "successful" completion that might be
required for dbms_output. In addition to generally useful logging, 
it (or something like it) is indispensable for debugging and development.

The type specification is declared with the *NOT FINAL* clause so that it is eligible
to be a supertype.

The method interface for *app_log_udt* is:
```sql
    -- member functions and procedures
    ,CONSTRUCTOR FUNCTION app_log_udt(p_app_name VARCHAR2)
        RETURN SELF AS RESULT
    ,FINAL MEMBER PROCEDURE app_log_udt_constructor(
        SELF IN OUT app_log_udt
        ,p_app_name VARCHAR2
    )
    ,FINAL MEMBER PROCEDURE log(p_msg VARCHAR2)
    ,FINAL MEMBER PROCEDURE log_p(p_msg VARCHAR2) -- prints with dbms_output and then logs
    -- these are not efficient, but not so bad in an exception block.
    -- You do not have to declare a variable to hold the instance because it is temporary
    ,FINAL STATIC PROCEDURE log(p_app_name VARCHAR2, p_msg VARCHAR2) 
    ,FINAL STATIC PROCEDURE log_p(p_app_name VARCHAR2, p_msg VARCHAR2) 
    -- should only be used by the schema owner, but only trusted application accounts
    -- are getting execute on this udt, so fine with me. If you are concerned, then
    -- break this procedure out standalone
    ,FINAL STATIC PROCEDURE purge_old(p_days NUMBER := 90)
```

Example Usage:
```sql
    DECLARE
        -- instantiate an object instance for app_name 'MY APP' which will automatically
        -- create the app_log_app entry if it does not exist
        v_log_obj   app_log_udt := app_log_udt('my app');
    BEGIN
        -- log a message for our app
        v_log_obj.log('START job xyz');
        ...
        v_log_obj.log('DONE job xyz');
        EXCEPTION WHEN OTHERS THEN
            -- log_p does DBMS_OUTPUT.PUT_LINE with the message then logs it
            v_log_obj.log_p('FAILED job xyz');
            v_log_obj.log_p('sql error: '||sqlerrm);
            RAISE;
    END;
```

There is a static procedure *purge_old* for pruning old log records that you can schedule.
It uses a technique that swaps a synonym between two base tables so that it does not interrupt 
ongoing log writes.

In addition to the underlying implementation tables, there are three views:

* app_log_base_v   
points to the base log table that is currently written to
* app_log_v   
joins on *app_id* to include the *app_name* string you provided to the constructor
* app_log_tail_v   
does the same as app_log_v except that it grabs only the most recent 20 records
and adds an elapsed time between log record entries. Useful for seeing how
long operations take. Also useful to grab the view definition SQL as a
start for your own more sophisticated analytic query, such as for reporting
job run times or other events.   

Example Output:
```
LEE@lee_pdb > select * from app_log_tail_v;
TIME_STAMP    ELAPSED     LOGMSG                                                                        APP_NAME
16:19.43.13               This will be the first message in the log after code deploy from app_log.sq   APP_LOG
16:20.16.86     33.7288   html mail sent to 1 recipients with 1 attachments                             HTML_EMAIL_UDT
17:07.40.01   #########   cursor2table called with p_widths.COUNT=0 but query column count is 3, so p   PDFGEN
17:16.05.64    505.6327   random sleep test starting for 1                                              APP_LOG
17:16.06.95      1.3096   random sleep test starting for 2                                              APP_LOG
17:16.12.72      5.7703   random sleep test starting for 3                                              APP_LOG
17:16.19.30      6.5817   random sleep test starting for 4                                              APP_LOG
17:16.25.66      6.3617   random sleep test starting for 5                                              APP_LOG
17:16.29.26      3.5910   random sleep test starting for 6                                              APP_LOG
17:16.34.20      4.9410   random sleep test starting for 7                                              APP_LOG
17:16.43.29      9.0910   random sleep test starting for 8                                              APP_LOG
17:16.50.42      7.1317   random sleep test starting for 9                                              APP_LOG
17:16.50.87       .4506   random sleep test starting for 10                                             APP_LOG
```

