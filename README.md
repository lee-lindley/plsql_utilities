# plsql_utilities

An Oracle PL/SQL Utility Library

Feel free to pick and choose, or just borrow code. Some of them you should keep my copyright
per the MIT license, others are already public domain. Included are

* Application Logging
* Application Parameter Facility
* Splitting of CSV Strings into Fields
* Create Zoned Decimal Strings from Numbers
* A few LOB Utilities
* A wrapper for DBMS_SQL that handles bulk fetches

# Content
1. [install.sql](#installsql)
2. [app_lob](#app_lob)
3. [app_log](#app_log)
4. [app_parameter](#app_parameter)
5. [arr_varchar2_udt](#arr_varchar2_udt)
6. [split](#split)
7. [to_zoned_decimal](#to_zoned_decimal)
8. [app_dbms_sql](#app_dbms_sql)

## install.sql

Runs each of these scripts in correct orderl

*split* depends upon [arr_varchar2_udt](#arr_varchar2_udt). Other than that, 
you can compile these separately or not at all. If you run *install.sql*
as is, it will install 6 of the 7 components (and sub-components).

The compile for *app_dbms_sql* is commented out. It is generally compiled from a repository
that includes *plsql_utilities* as a submodule.

## app_lob

Four LOB functions and procedures that should be in *DBMS_LOB* IMHO. The names are description enough.

- blobtofile
```sql
    PROCEDURE blobtofile(
        p_blob                      BLOB
        ,p_directory                VARCHAR2
        ,p_filename                 VARCHAR2
    );
```
- clobtoblob
```sql
    FUNCTION clobtoblob(
         p_clob                     CLOB
    ) RETURN BLOB
    ;
```
- filetoblob
```sql
    FUNCTION filetoblob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN BLOB
    ;
```
- filetoclob
```sql
    -- TO_CLOB(BFILENAME(dir,file_name)) works in a sql statement, but not in pl/sql directly as of 12.2.
    FUNCTION filetoclob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN CLOB
    ;
```

## app_log

A lightweight and fast general purpose database application logging facility, 
the core is an object oriented user defined type with methods for writing 
time-stamped log records to a table.  Since the autonomous transactions write independently,
you can get status of the program before "successful" completion that might be
required for dbms_output. In addition to generally useful logging, 
it (or something like it) is indispensable for debugging and development.

The method interface is:
```sql
    -- member functions and procedures
    ,CONSTRUCTOR FUNCTION app_log_udt(p_app_name VARCHAR2)
        RETURN SELF AS RESULT
    ,MEMBER PROCEDURE log(p_msg VARCHAR2)
    ,MEMBER PROCEDURE log_p(p_msg VARCHAR2) -- prints with dbms_output and then logs
    -- these are not efficient, but not so bad in an exception block.
    -- You do not have to declare a variable to hold the instance because it is temporary
    ,STATIC PROCEDURE log(p_app_name VARCHAR2, p_msg VARCHAR2) 
    ,STATIC PROCEDURE log_p(p_app_name VARCHAR2, p_msg VARCHAR2) 
    -- should only be used by the schema owner, but only trusted application accounts
    -- are getting execute on this udt, so fine with me. If you are concerned, then
    -- break this procedure out standalone
    ,STATIC PROCEDURE purge_old(p_days NUMBER := 90)
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
## app_parameter

General purpose application parameter set/get functionality with auditable history of changes.
Use for storing values that might otherwise be hard-coded such as email addresses,
application configuration information, and database instance specific settings (as
might be important to differentiate between production and test environments).

Uses a common Data Warehouse pattern for "end dating" rather than deleting records,
thus leaving an audit trail inside the main table.
Only records with NULL *end_date* are "live" records.
Records that are logically deleted have the *end_date* and *end_dated_by*
fields populated. 
A logical update consists of a logical delete as described above plus an insert with
the fields *end_date* and *end_dated_by* set to NULL.

The standalone function *get_app_parameter* uses RESULT_CACHE with the intent of being
fast in a database with many different programs using the facility often.
That may be overkill for your scenario, but it doesn't hurt anything.
It returns NULL if the parameter name does not exist in the table.

```sql
    FUNCTION get_app_parameter(p_param_name VARCHAR2) RETURN VARCHAR2 RESULT_CACHE
```

Package *app_parameter* provides procedures for inserting and "end dating" records. A 
logical update with *create_or_replace* performs both operations. Grants to this package 
may well be different than those to *get* the parameter values.
The package provides the following public subprograms:

```sql
    -- likely seldom used, "end date" a parameter without replacing it
    PROCEDURE end_app_parameter(p_param_name VARCHAR2); 
    --
    -- both inserts and updates
    --
    PROCEDURE create_or_replace(p_param_name VARCHAR2, p_param_value VARCHAR2);

    -- these are specialized for a scenario where production data is cloned to a test system 
    -- and you do not want the parameters from production used to do bad things in the test system
    -- before you get a chance to update them. Obscure and perhaps not useful to you.
    FUNCTION is_matching_database RETURN BOOLEAN;
    FUNCTION get_database_match RETURN VARCHAR2;
    PROCEDURE set_database_match; -- do this after updating the other app_parameters following a db refresh from production
```

The implemenation includes two triggers to prevent a well meaning coworker from performing invalid
updates or deletes rather than using the procedures (or doing them correctly). These
also add the userid and timestamp for new records that do not have values provided.
This level of control is likely overkill, but it is nice to be able to
tell an auditor or security reviewer that you have auditable change history on an important table 
that you will probably want to be able to update in production without a code promotion.

## arr_varchar2_udt

User Defined Type Table of VARCHAR2(4000) required for some of these utilities. If you already
have one of these, by all means use it instead. Replace all references to *arr_varchar2_udt*
in the other files you deploy.

## split

A function to split a comma separated value string that follows RFC4180 
into an array of strings.

Treat input string *p_s* as following the Comma Separated Values (csv) format 
(not delimited, but separated) and break it into an array of strings (fields) 
returned to the caller. This is overkill for the most common case
of simple separated strings that do not contain the separator char and are 
not quoted, but if they are double quoted fields, this will handle them 
appropriately including the quoting of " within the field.

We comply with RFC4180 on CSV format (for what it is worth) while also 
handling the mentioned common variants like backwacked quotes and 
backwacked separators in non-double quoted fields that Excel produces.

See https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml

The problem turned out to be much more complex than I thought when starting the work.
If you like playing with regular expressions, take a gander and tell me if you can 
do better. (really! I like to learn.)

```sql
FUNCTION split (
    p_s             VARCHAR2
    ,p_separator    VARCHAR2    DEFAULT ','
    ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also "unquotes" \" and "" pairs within a double quotes string to "
) RETURN arr_varchar2_udt DETERMINISTIC
-- when p_s IS NULL returns initialized collection with COUNT=0
```

## to_zoned_decimal

Format a number into a mainframe style Zoned Decimal. The use case is producing a 
fixed width text file to send to a mainframe. For example:

Number: 6.80    
Format: S9(7)V99   
Arguments: p_number=>6.8, p_digits_before_decimal=>7, p_digits_after_decimal=>2   
Result: '00000068{'    

```sql
FUNCTION to_zoned_decimal(
    p_number                    NUMBER
    ,p_digits_before_decimal    BINARY_INTEGER          -- characteristic S9(7)V99 then 7
    ,p_digits_after_decimal     BINARY_INTEGER := NULL  -- mantissa       S9(7)V99 then 2
) RETURN VARCHAR2 DETERMINISTIC
```

Converting from zoned decimal string to number is a task you would perform with sqlldr or external table.
The sqlldr driver has a conversion type for zoned decimal ( for S9(7)V99 use ZONED(9,2) ).

## app_dbms_sql

Given a SYS_REFCURSOR of unknown select list, set up to bulk collect the column
values into arrays, then return each row as an array of strings
converted per specification.

You have no reason to use this package directly because you can just as easily
do the conversion to text in SQL. The package is used by a facility to create CSV rows
(taking care of proper quoting), as well as a facility that creates PDF report files.

Unless you are trying to create a generic utility that can handle any query sent it's way,
you almost certainly would be better off using native dynamic sql, or at worst, using DBMS_SQL
directly. 

Mainly I got sick of handling the details of DBMS_SQL array fetches which essentially
require you to know what the columns are because you have to declare variables for
each column type (and the only reason I needed DBMS_SQL was because I don't know the
select list at compile time!!!). This thing is exceedingly ugly, but in return you 
get a simple interface to something that turned out to be complicated to do efficiently.
Most implementations I examined either used DBMS_SQL in row by row mode, or else after doing
a bulk fetch, copied the entire bulk set of column values to get the ones desired for a single row
(repeating on every row). It baffled me until I tried to do it myself. 

DBMS_SQL is an
imperfect interface. This is a little better, but only because we are returning strings for all values.
We could use the *anydata* type perhaps, but then the consumer must have a big case statement deciding
what to do with each value. I can't find an easy button here. It is a hard problem.

```sql
    -- Main entry point. This is how you get the party started.
    FUNCTION convert_cursor(
        p_cursor        SYS_REFCURSOR
        ,p_bulk_count   BINARY_INTEGER := 100
    ) RETURN BINARY_INTEGER;

    -- you should call this when finished, but it deletes the context
    -- so be sure and grab row_count first if you need it.
    -- You should also put it in your exception block.
    PROCEDURE close_cursor(
        p_ctx    IN OUT BINARY_INTEGER
    );

    TYPE t_arr_varchar2 IS TABLE OF VARCHAR2(32767);

    -- After calling convert_cursor, you call get_next_column_values in a loop
    -- until it returns null. The other methods are just candy.
    --
    -- will return NULL when no more rows
    -- The returned array values are the values of each query column converted to string
    FUNCTION get_next_column_values(
        p_ctx               BINARY_INTEGER
        ,p_num_format       VARCHAR2 := 'tm9'
        ,p_date_format      VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format  VARCHAR2 := NULL
    ) RETURN t_arr_varchar2;

    -- and the candy...
    FUNCTION get_row_count(p_ctx BINARY_INTEGER) RETURN BINARY_INTEGER;
    FUNCTION get_desc_tab3(p_ctx BINARY_INTEGER) RETURN DBMS_SQL.desc_tab3;
    FUNCTION get_column_names(p_ctx BINARY_INTEGER) RETURN t_arr_varchar2;
```


