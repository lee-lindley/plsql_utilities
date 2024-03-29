# app_log

A lightweight and fast general purpose database application logging facility, 
the core is an object oriented user defined type (UDT) with methods for writing 
high precision, time-stamped log records to a table.  Since the autonomous transactions write independently,
you can retrieve status of the program before "successful" completion that might be
required for DBMS_OUTPUT. In addition to generally useful logging, 
it (or something like it) is indispensable for debugging, development, and tuning.

<!--
| app_log ER Diagram |
|:--:|
| ![app_log Use Case Diagram](../images/app_log_use_case.gif) |
-->
<p align="center">app_log_udt Use Case Diagram</p>
<p align="center"><img src="../images/app_log_use_case.png"></p>

Additional functionality can be built upon the basic log message
by standardizing the content. Comma
separated Name=Value pairs (a la JSON) are a fine pattern to implement in log messages.

The prime directive is to avoid imposing a measurable cost in resources,
nor be a point of contention or blocking for the application. Consumers of
the log are expected to be developers and support personnel who can afford to put
a little elbow grease into extracting information. You can parse the messages,
write analytic queries to reach between messages,
and afford to read the entire log table. We do not coddle you with indexes or
extra fields to make querying easier. You don't need it and the application writing the log
should not bear the burden of providing it.

*app_log_udt* was implemented on a large, multi-node Exadata cluster for an application that served
SOA packages to a web front-end. During peak hours the application was writing more than 300,000 log
records per minute with no measurable performance difference observable between logging turned on and off.
This was true even during a log purge operation.

# Design

A lookup table (*app_log_app*) maintains unique keys by an "application identifier" *app_name*. The UDT code
insures referential integrity when it writes log records (rather than a database referential integrity constraint
which has a small cost on every write).

There are a pair of log record tables, one of which is pointed to by the primary synonym *app_log*. A maintentace operation
swaps the synonym when purging old records. A view *app_log_base_v* points to the currently active base log
table via the synonym. Queries may use the synonym or the view. 

Convenience views join the key and log tables as well as provide example analytic code for displaying
the time between records.

<!--
| app_log ER Diagram |
|:--:|
| ![app_log ER Diagram](../images/app_log_er.png) |
-->
<p align="center">app_log ER Diagram</p>
<p align="center"><img src="../images/app_log_er.png"></p>

# Details
The type specification is declared with the *NOT FINAL* clause so that it is eligible
to be a supertype. (See *app_job_log_udt* for an example subtype).

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

If the message is longer than 4000 characters, *log* will write each 4000 character chunk in sequential records.

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

