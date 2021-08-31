# plsql_utilities

An Oracle PL/SQL Utility Library

Feel free to pick and choose, or just borrow code. Some of them you should keep my copyright
per the MIT license, others are already public domain. Included are

* Application Logging
* Application Parameter Facility
* Splitting of CSV Strings into Fields
* Create Zoned Decimal Strings from Numbers
* A few LOB Utilities
* A zip archive handler courtesy of Anton Scheffer
* An Object wrapper for *as_zip*
* A wrapper for DBMS_SQL that handles bulk fetches

# Content
1. [install.sql](#installsql)
2. [app_lob](#app_lob)
3. [app_log](#app_log)
4. [app_parameter](#app_parameter)
5. [arr_arr_clob_udt](#arr_arr_clob_udt)
6. [arr_varchar2_udt](#arr_varchar2_udt)
7. [split](#split)
8. [to_zoned_decimal](#to_zoned_decimal)
9. [as_zip](#as_zip)
10. [app_zip](#app_zip)
11. [app_dbms_sql](#app_dbms_sql)

## install.sql

Runs each of these scripts in correct order.

*split* depends upon [arr_varchar2_udt](#arr_varchar2_udt). 

*app_zip* depends on [as_zip](#as_zip), [app_lob](#app_lob), [arr_varchar2_udt](#arr_varchar2_udt), and [split](#split).

Other than those, you can compile these separately or not at all. If you run *install.sql*
as is, it will install 10 of the 11 components (and sub-components).

The compile for [app_dbms_sql](#app_dbms_sql) is commented out. It is generally compiled from a repository
that includes *plsql_utilities* as a submodule. It requires [arr_arr_clob_udt](#arr_arr_clob_udt)
and [arr_varchar2_udt](#arr_varchar2_udt).

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

## arr_arr_clob_udt

Two user defined types. *arr_clob_udt* is a TABLE OF CLOB. *arr_arr_clob_udt* is a 
TABLE OF *arr_clob_udt* (or array of arrays).
If you already
have these in some form, by all means use them instead. Replace all references to *arr_arr_clob_udt*
(do this one first so you do not match *arr_clob_udt*)
and *arr_clob_udt* in the other files you deploy.

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

## as_zip

A package for reading and writing ZIP archives as BLOBs published by Anton Scheffer
[compress-gzip-and-zlib](https://technology.amis.nl/it/utl_compress-gzip-and-zlib/).

Other than splitting into .pks and .pkb files, the only change I made was declaring
the package to use invoker rights (AUTHID CURRENT_USER). The reason is that it can write
a file to a directory and that priviledge should depend on the caller.

Somewhere along the way I picked up a version that added an optional Date argument to *add1file*.
It is a slight mismatch from the above link. Seems useful though. If you already have as_zip
installed without it, you might choose to remove the optional date argument from methods in *app_zip*.

## app_zip

An object type wrapper for [as_zip](#as_zip), it adds methods for adding clobs and for
adding multiple files at once from a comma separated list string. The functionality
is exclusively for creating the zip archive BLOB. If you want to list the file content
or grab a file from a zip, use *as_zip* directly.

The method interface is:
```sql
    ,CONSTRUCTOR FUNCTION app_zip_udt RETURN SELF AS RESULT
    -- once you call get_zip, the object blob is no longer useful. You cannot add to it
    -- nor can you call get_zip again.
    ,MEMBER FUNCTION get_zip RETURN BLOB
    ,MEMBER PROCEDURE add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    ,MEMBER PROCEDURE add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    ,MEMBER PROCEDURE add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- comma separated list of file names
    ,MEMBER PROCEDURE add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- names should have dir as first component before slash
    ,MEMBER PROCEDURE add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
```

Example:
```sql
    DECLARE
        l_zip   BLOB;
        l_z     app_zip_udt;
    BEGIN
        l_z := app_zip_udt;
        l_z.add_clob('some text in a clob', 'folder_x/y.txt');
        l_z.add_files('TMP_DIR', 'x.txt,y.xlsx,z.csv');
        l_z.add_files('TMP_DIR/a.txt, TMP_DIR/b.xlsx, TMP_DIR/c.csv');
        l_zip := l_z.get_zip;
        INSERT INTO mytable(file_name, blob_content) VALUES ('my_zip_file.zip', l_zip);
        COMMIT;
    END;
```
Examples with method chaining:
```sql
    -- chaining function calls without declaring a variable
    INSERT INTO mytable(file_name, blob_content)
        VALUES('my_zip_file.zip'
            ,app_zip_udt().add_files('TMP_DIR/a.txt, TMP_DIR/b.xlsx, TMP_DIR/c.csv').get_zip()
        )
    COMMIT;

    SELECT app_zip_udt().add_file(m.blob_content, m.file_name).get_zip() AS zip_file_blob
    FROM mytable m
    WHERE m.file_name = 'my_big_file.csv'
    ;

    SELECT app_zip_udt().add_file('TMP_DIR', 'some_big_file.csv').get_zip() AS zip_file_blob FROM DUAL;
```
The *test* subdirectory of the *app_zip* folder may be helpful for seeing it in action.


## app_dbms_sql

*app_dbms_sql_udt* is a base type that cannot be instantiated.

*app_dbms_sql_str_udt* is a subtype of *app_dbms_sql_udt*. It can be instantiated, tested
and used standalone or as a supertype.

Given a SYS_REFCURSOR of unknown select list, *app_dbms_sql_str_udt* sets up to bulk collect the column
values into arrays, then return each row as an array of strings
converted per optional TO_CHAR conversion specification.

You have no reason to use this package directly because you can just as easily
do the conversion to text in SQL. The type is used by a facility to create CSV rows
(taking care of proper quoting), as well as a facility that creates PDF report files.

Unless you are trying to create a generic utility (such as those just mentioned) 
that can handle any query sent it's way,
you almost certainly would be better off using native dynamic sql, or at worst, using DBMS_SQL
directly. 

DBMS_SQL is an imperfect interface. This is a little better, but only because we are 
returning strings for all values.  The *ANYDATA* interface is grossly inefficient used directly 
inside PL/SQL as each call goes out to the SQL engine, so it is not a viable answer.
It is a hard problem, but an easy button (or at least easier) may be available
with Polymorphic Table Functions come Oracle 18c (I'm still supporting 12c), though that seems 
overly complicated on first blush too. 

### app_dbms_sql_udt

```sql
    ,FINAL MEMBER PROCEDURE base_constructor(
        SELF IN OUT NOCOPY      app_dbms_sql_udt
        ,p_cursor               SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
    )
    -- the DBMS_SQL context number. You can use it to get desc_tab
    -- if you need it.
    ,FINAL MEMBER FUNCTION get_ctx            RETURN INTEGER
    ,FINAL MEMBER FUNCTION get_column_names   RETURN arr_varchar2_udt
    ,FINAL MEMBER FUNCTION get_column_types   RETURN arr_varchar2_udt
    -- should only call after completing read of all rows
    ,FINAL MEMBER FUNCTION get_row_count RETURN INTEGER
    --
    -- you probably have no need to use this procedure
    -- which is called from get_next_column_values in subtypes
    ,NOT INSTANTIABLE MEMBER PROCEDURE fetch_rows(
        SELF IN OUT NOCOPY  app_dbms_sql_udt
    )
    -- expects to call fetch_rows which must set row_index, rows_fetched and total_rows_fetched
    ,FINAL MEMBER PROCEDURE fetch_next_row(
        SELF IN OUT NOCOPY  app_dbms_sql_udt
    )
```

### app_dbms_sql_str_udt

Inherits methods from *app_dbms_sql_udt*.

```sql
   ,CONSTRUCTOR FUNCTION app_dbms_sql_str_udt(
        p_cursor                SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
        ,p_default_num_fmt      VARCHAR2 := 'tm9'
        ,p_default_date_fmt     VARCHAR2 := 'MM/DD/YYYY'
        ,p_default_interval_fmt VARCHAR2 := NULL
    ) RETURN SELF AS RESULT
    -- you only need this procedure if you are subtyping app_dbms_sql_udt.
    ,FINAL MEMBER PROCEDURE app_dbms_sql_str_constructor(
        SELF IN OUT NOCOPY      app_dbms_sql_str_udt
        ,p_cursor               SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
        ,p_default_num_fmt      VARCHAR2 := 'tm9'
        ,p_default_date_fmt     VARCHAR2 := 'MM/DD/YYYY'
        ,p_default_interval_fmt VARCHAR2 := NULL
    )
    -- provide a column specific TO_CHAR conversion format
    ,FINAL MEMBER PROCEDURE set_fmt(
        SELF IN OUT NOCOPY  app_dbms_sql_str_udt
        ,p_col_index        BINARY_INTEGER
        ,p_fmt              VARCHAR2
    )
    -- each call returns a row as an array of clob values in p_arr_clob
    ,FINAL MEMBER PROCEDURE get_next_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
        ,p_arr_clob OUT NOCOPY arr_clob_udt
    ) 
    --
    -- you probably have no need to use these to procedures
    -- which are called from get_next_column_values
    ,FINAL MEMBER PROCEDURE get_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
        ,p_arr_clob OUT NOCOPY arr_clob_udt
    ) 
    ,OVERRIDING MEMBER PROCEDURE fetch_rows(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
    )
```
