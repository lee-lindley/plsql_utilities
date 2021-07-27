# plsql_utilities

A PL/SQL Utility Library

Feel free to pick and choose, or just borrow code. Some of them you should keep my copyright
per the MIT license, others are already public domain.

# Content
1. [install.sql](#installsql)
2. [app_lob](#app_lob)
3. [app_log](#app_log)
4. [app_parameter](#app_parameter)
5. [arr_varchar2_udt](#arr_varchar2_udt)
6. [html_email_udt](#html_email_udt)
7. [split](#split)
8. [to_zoned_decimal](#to_zoned_decimal)

## install.sql

Runs each of these scripts in correct order and with compile options.

## app_lob

Several LOB functions and procedures that should be in *DBMS_LOB*. The names are description enough.

- file_to_blob
```sql
    PROCEDURE blob_to_file(
        p_filename                 VARCHAR2
        ,p_directory                VARCHAR2
        ,p_blob                     BLOB
$if $$use_app_log $then
        ,p_logger                   app_log_udt DEFAULT NULL -- we can use yours if you want the messages to have your applicaton id
$end
    );
```
- clob_to_blob
```sql
    FUNCTION clob_to_blob(
         p_data                     CLOB
$if $$use_app_log $then
         ,p_logger                  app_log_udt DEFAULT NULL
$end
    ) RETURN BLOB
    ;
```
- blob_to_file
```sql
    FUNCTION file_to_blob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
$if $$use_app_log $then
        ,p_logger                   app_log_udt DEFAULT NULL -- we can use yours if you want the messages to have your applicaton id
$end
    ) RETURN BLOB
    ;
```

## app_log

A lightweight and fast general purpose database application logging facility, 
the core is an object oriented user defined type with methods for writing 
log records to a table.  Since the autonomous transactions write independently,
you can get status of the program before "succesful" completion that might be
required for dbms_output. In addition to generally useful logging, 
it (or something like it) is indispensable for debugging and development.

Example:
```sql
    DECLARE
        -- instantiate an object instance for app_name 'bnft' which will automatically
        -- create the app_log_app entry if it does not exist
        v_log_obj   app_log_udt := app_log_udt('bnft');
    BEGIN
        -- log a message for our app
        v_log_obj.log('whatever my message: '||sqlerrm);
        -- same but also do DBMS_OUTPUT.PUT_LINE with the message too
        v_log_obj.log_p('whatever my message: '||sqlerrm);
    END;
```

There is a static procedure *purge_old* for pruning old log records that you can schedule.
It uses a method that swaps a synonym between two base tables so that it does not interrupt 
ongoing log writes.

In addition to the underlying implementation tables there are three views:

* app_log_base_v 
points to the base log table that is currently written to
* app_log_v 
joins on *app_id* to include the *app_name* string you provided to the constructor
* app_log_tail_v 
does the same as app_log_v except that it grabs only the most recent 20 records
and adds an elapsed time between log record entries. Useful for seeing how
long operations take.  Example:
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
## app_parameter

General purpose application parameter set/get functionality with auditable history of changes.
Use for storing values that might otherwise be hard-coded such as email addresses,
application configuration information, and database instance specific settings (such as
might be important to differentiate between production and test environments).

The standalone function *get_app_parameter* uses RESULT_CACHE with the intent of being
fast in a database with a lot of activity where many different programs use the facility.
For many that will be overkill. It returns NULL if the parameter name does not exist in the table.

```sql
    FUNCTION get_app_parameter(p_param_name VARCHAR2) RETURN VARCHAR2 RESULT_CACHE
```

Package *app_parameter* provides procedures for inserting and "end dating" records. A 
logical update performs both operations. Grants to this package may well be different than 
those to get the parameter values. The package provides the following public subprograms:

```sql
    PROCEDURE end_app_parameter(p_param_name VARCHAR2); -- probably very seldom used to get rid of one
    -- both inserts and updates
    PROCEDURE create_or_replace(p_param_name VARCHAR2, p_param_value VARCHAR2);

    -- these are specialized for a scenario where production data is cloned to a test system 
    -- and you do not want the parameters from production used to do bad things in the test system
    -- Obscure and probably not useful to you.
    FUNCTION is_matching_database RETURN BOOLEAN;
    FUNCTION get_database_match RETURN VARCHAR2;
    PROCEDURE set_database_match; -- do this after updating the other app_parameters following a db refresh from prod
```

The implemenation includes two triggers that attempt to ensure that noone does invalid
updates or deletes rather than using the procedures that "end date" existing records. These
also add the userid and timestamp for new records that do not have values provided.
Writes to the table are rare and this kind of control is likely overkill, but it is nice to be able to
tell an auditor that you have this control and history on an important table that you can
likely update in production without a code promotion.

## arr_varchar2_udt

User Defined Type Table of strings required for some of these utilities. If you already
have one of these, by all means use it instead. Replace all references to *arr_varchar2_udt*
in the other files you deploy.

## html_email_udt

An Object type for constructing and sending an HTML email, optionally with
attachments. Although object attributes cannot be made private, you have 
no need for them. The interface is through the methods: 
```sql
    CONSTRUCTOR FUNCTION html_email_udt(
        p_to_list           CLOB DEFAULT NULL
        ,p_cc_list          CLOB DEFAULT NULL
        ,p_bcc_list         CLOB DEFAULT NULL
        ,p_from_email_addr  VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_reply_to         VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_smtp_server      VARCHAR2 DEFAULT 'localhost'
        ,p_subject          VARCHAR2 DEFAULT NULL
        ,p_body             CLOB DEFAULT NULL
        ,p_log              app_log_udt DEFAULT NULL -- optional at compile time
    ) RETURN SELF AS RESULT
    ,MEMBER PROCEDURE send
    ,MEMBER PROCEDURE add_paragraph(p_clob CLOB)
    ,MEMBER PROCEDURE add_to_body(p_clob CLOB)
    ,MEMBER PROCEDURE add_table_to_body( -- see cursor_to_table
        p_sql_string    CLOB            := NULL
        ,p_refcursor    SYS_REFCURSOR   := NULL
        ,p_caption      VARCHAR2        := NULL
    )
    -- these take strings that can have multiple comma separated email addresses
    ,MEMBER PROCEDURE add_to(p_to VARCHAR2) 
    ,MEMBER PROCEDURE add_cc(p_cc VARCHAR2)
    ,MEMBER PROCEDURE add_bcc(p_bcc VARCHAR2)
    --
    ,MEMBER PROCEDURE add_subject(p_subject VARCHAR2)
    ,MEMBER PROCEDURE add_attachment(
        p_file_name     VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
    )
```

As a bonus it provides a static function to convert a cursor or query string 
into a CLOB containing an HTML table. You can include that in the email
or use it for a different purpose. It is called by member method *add_table_to_body*.
```sql
    --Note: that if the cursor does not return any rows, we silently pass back an empty clob
    ,STATIC FUNCTION cursor_to_table(
        -- pass in a string. 
        -- Unfortunately any tables that are not in your schema 
        -- will need to be fully qualified with the schema name. The open cursor version does
        -- not share this issue.
        p_sql_string    CLOB            := NULL
        -- pass in an open cursor. This is better for my money.
        ,p_refcursor     SYS_REFCURSOR  := NULL
        -- if provided, will be the caption on the table, generally centered on the top of it
        -- by most renderers.
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
```

There is a nice example as a comment in the type definition which I reproduce here:
```sql
DECLARE
    v_email         html_email_udt;
    v_src           SYS_REFCURSOR;
    v_query         VARCHAR2(32767) := q'!SELECT --+ no_parallel
            v.view_name AS "View Name"
            ,c.comments AS "Comments"
        FROM dictionary d
        INNER JOIN all_views v
            ON v.view_name = d.table_name
        LEFT OUTER JOIN all_tab_comments c
            ON c.table_name = v.view_name
        WHERE d.table_name LIKE 'ALL%'
        ORDER BY v.view_name
        FETCH FIRST 40 ROWS ONLY!';
    --
    -- Because you cannot CLOSE/ReOPEN a dynamic sys_refcursor variable directly,
    -- you must regenerate it and assign it. Weird restriction, but do not
    -- try to fight it by opening it in the main code twice. Get a fresh copy from a function.
    FUNCTION l_getcurs RETURN SYS_REFCURSOR IS
        l_src       SYS_REFCURSOR;
    BEGIN
        OPEN l_src FOR v_query;
        RETURN l_src;
    END;
BEGIN
    v_email := html_email_udt(
        p_to_list           => 'lee@linux2.localdomain, root@linux2.localdomain'
        ,p_from_email_addr  => 'nobody@linux2.localdomain'
        ,p_reply_to         => 'nobody@linux2.localdomain'
        ,p_subject          => 'A sample email from html_email_udt'
        ,p_smtp_server      => 'localhost'
    );
    v_email.add_paragraph('We constructed and sent this email with html_email_udt.');
    v_src := l_getcurs;
    --v_email.add_to_body(html_email_udt.cursor_to_table(p_refcursor => v_src, p_caption => 'DBA Views'));
    v_email.add_table_to_body(p_refcursor => v_src, p_caption => 'DBA Views');
    -- we need to close it because we are going to open again.
    -- The called package may have closed it, but must be sure or nasty
    -- bugs/caching can happen.
    BEGIN
        CLOSE v_src;
    EXCEPTION WHEN invalid_cursor THEN NULL;
    END;

    -- https://github.com/mbleron/ExcelGen
    DECLARE
        l_xlsx_blob     BLOB;
        l_ctxId         ExcelGen.ctxHandle;
        l_sheet_handle  BINARY_INTEGER;
    BEGIN
        v_src := l_getcurs;
        l_ctxId := ExcelGen.createContext();
        l_sheet_handle := ExcelGen.addSheetFromCursor(l_ctxId, 'DBA Views', v_src, p_tabColor => 'green');
        BEGIN
            CLOSE v_src;
        EXCEPTION WHEN invalid_cursor THEN NULL;
        END;
        ExcelGen.setHeader(l_ctxId, l_sheet_handle, p_frozen => TRUE);
        v_email.add_attachment(p_file_name => 'dba_views.xlsx', p_blob_content => ExcelGen.getFileContent(l_ctxId));
        excelGen.closeContext(l_ctxId);
    END;
    v_email.add_paragraph('The attached spreadsheet should match what is in the html table above');
--dbms_output.put_line(v_email.body);

    v_email.send;
END;
```

## split

A function to split a comma separated value string that follows RFC4180 
into an array of strings.
(See https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml)

Although it is overkill for the most common use cases, it handles everything the 
RFC describes with respect to quoting and is not limited to comma as a separator.
In particular if you have CSV records from Microsoft Excel, this will parse them
correctly even when they have embedded separator characters in the values. The
problem turned out to be much more complex than I thought it would be when I started.
If you like playing with regular expressions, take a gander and tell me if you can 
do better. (really! I like to learn.)

```sql
FUNCTION split (
         p_s            VARCHAR2
        ,p_separator    VARCHAR2    DEFAULT ','
        ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
        ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also "unquotes" \" and "" pairs within a double quotes string to "
) RETURN arr_varchar2_udt
```

## to_zoned_decimal

Format a number into a mainframe style Zoned Decimal. (example: 
S9(7)V99 format 6.80 => '00000068{')

```sql
FUNCTION to_zoned_decimal(
    p_number                NUMBER
    ,p_length               BINARY_INTEGER          -- S9(7)V99 then 7
    ,p_digits_after_decimal BINARY_INTEGER := NULL  -- S9(7)V99 then 2
) RETURN VARCHAR2 DETERMINISTIC
```
