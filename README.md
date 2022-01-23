# plsql_utilities

An Oracle PL/SQL Utility Library

Feel free to pick and choose, or just borrow code. Some of them you should keep my copyright
per the MIT license, others are already public domain. Included are

* Application Logging
* Application Parameter Facility
* Perlish Utility User Defined Type
    * Transforming Perl-style Regexp to Oracle RE
    * Splitting of CSV Strings into Fields
    * Create private temporary table from CSV clob
    * methods that mimic the Perl *map*, *join* and *sort* methods in a chain of calls
* Parse CSV data into Oracle resultset
* Create Zoned Decimal Strings from Numbers
* A few LOB Utilities
* A zip archive handler courtesy of Anton Scheffer
* An Object wrapper for *as_zip*
* A wrapper for DBMS_SQL that handles bulk fetches (likely superceded by Polymorphic Table Functions)

# Content
1. [install.sql](#installsql)
2. [app_lob](#app_lob)
3. [app_log](#app_log)
4. [app_job_log](#app_job_log)
5. [app_parameter](#app_parameter)
6. [arr_arr_clob_udt](#arr_arr_clob_udt)
7. [arr_varchar2_udt](#arr_varchar2_udt)
8. [arr_integer_udt](#arr_integer_udt)
9. [perlish_util_udt](#perlish_util_udt)
10. [csv_to_table](#csv_to_table)
11. [to_zoned_decimal](#to_zoned_decimal)
12. [as_zip](#as_zip)
13. [app_zip](#app_zip)
14. [app_dbms_sql](#app_dbms_sql)

## install.sql

*install.sql* runs each of these scripts in correct order.

There are sqlplus *define* statements at the top of the script for naming basic collection types.
In this document I refer to them with **arr\*X\*udt** names, but you can follow your own naming guidelines
for them. If you already have types with the same characteristics, put those into the *define* statements
and then set the corresponding **compile\*** define values to FALSE.

*perlish_util_udt* and *csv_to_table* depend upon [arr_varchar2_udt](#arr_varchar2_udt) .

*app_zip* depends on [as_zip](#as_zip), [app_lob](#app_lob), [arr_varchar2_udt](#arr_varchar2_udt), and [perlish_util_udt](#perlish__util_udt) (for split_csv).

*app_job_log* depends on [app_log](#app_log), and optionally on [html_email](https://github.com/lee-lindley/html_email)
if you set the compile directive define use_html_email to 'TRUE' in *app_job_log/install_app_job_log.sql*.

Other than those, you can compile these separately or not at all. If you run *install.sql*
as is, it will install 12 of the 14 components (and sub-components).

The compile for [csv_to_table](#csv_to_table) is set to FALSE. The complexity is excessive
for most use cases which can be fulfilled using the [perlish_util_udt](#perlish_util_udt) *split_clob_to_lines*,
constructor, and *get* methods. See examples. I have not given up on it yet though. If I come up
with use cases that make sense, I'll reconsider making it a first class citizen.

The compile for [app_dbms_sql](#app_dbms_sql) is set to FALSE. It is generally compiled from a repository
that includes *plsql_utilities* as a submodule. It requires [arr_arr_clob_udt](#arr_arr_clob_udt),
[arr_integer_udt](#arr_integer_udt), and [arr_varchar2_udt](#arr_varchar2_udt).

## app_lob

Package *app_lob* supplies four LOB functions and procedures that should be in *DBMS_LOB* IMHO. The names are description enough.

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
Example:
```sql
    SELECT app_lob.filetoblob('TMP_DIR', 'some_file_i_wrote.zip') AS zip_file FROM dual;
```
Then from sqldeveloper or toad you can save the resulting BLOB to a file on your client machine.

## app_log

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
## app_job_log

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
        v_log   app_job_log('MY_DAILY_JOB', 'appsupport@mycompany.com');
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

## arr_varchar2_udt

User Defined Type Table of VARCHAR2(4000) required for some of these utilities. 

## arr_integer_udt

User Defined Type Table of INTEGER required for some of these utilities. 

## perlish_util_udt

It isn't Perl, but it makes some Perlish things a bit easier in PL/SQL. We also get
handy methods for splitting Comma Separated Value (CSV) text into lines and fields,
which you can use independent of the Perlish methods, and even one that turns a CSV
clob into a private temporary table.

> There is valid argument
that when you are programming in a language you should use the facilities of that language, 
and that attempting to layer the techniques of another language upon it is a bad idea. I see the logic
and partially agree. I expect those who later must support my work that uses this utility will curse me. Yet
PL/SQL really sucks at some string and list related things. This uses valid PL/SQL object techniques
to manipulate strings and lists in a way that is familiar to Perl hackers. 

A *perlish_util_udt* object instance holds an *arr_varchar2_udt* collection attribute which you will use when employing the following member methods;

- map
- join
- sort
- get
- combine

All member methods except *get* have static alternatives using *arr_varchar2_udt* parameters and return types, so you
are not forced to use the Object Oriented syntax.

It has static method *split_csv* (returns *arr_varchar2_udt*) that 
formerly lived as a standalone function in the plsql_utilities library as *split*.
We have a static method *split_clob_to_lines* that returns an *arr_varchar2_udt* collection
of "records" from what is assumed to be a CSV file. It parses for CSV syntax when splitting the lines
which means there can be embedded newlines in text fields in a "record".

There is a static procedure *create_ptt_csv* that consumes a CLOB containing lines of CSV data
and turns it into a private temporary table for your session. The PTT has column names from the
first line in the CLOB.

It also has a static method named *transform_perl_regexp* that has nothing to do with arrays/lists, but is Perlish.

Most of the member methods are chainable which is handy when you are doing a series of operations.

### Examples

Example 1:
```sql
    SELECT perlish_util_udt(arr_varchar2_udt('one', 'two', 'three', 'four')).sort().join(', ') FROM dual;
    -- Or using split_csv version of the constructor
    SELECT perlish_util_udt('one, two, three, four').sort().join(', ') FROM dual;
```
Output:

    "four, one, three, two"

Example 2:
```sql
    SELECT perlish_util_udt('id, type').map('t.$_ = q.$_').join(' AND ') FROM dual;
```
Output:

    "t.id = q.id AND t.type = q.type"

Example 3:
```sql
    SELECT perlish_util_udt('id, type').map('  t.$_ = q.$_').join(',') FROM dual;
```

    "  t.id = q.id,
        t.type = q.type"
Example 4:
```sql
    SELECT perlish_util_udt('id, type').map('x.p.get($##index_val##) AS "$_"').join(', ') FROM dual;
```
    x.p.get(1) AS "id", x.p.get(2) AS "type"

There are static versions of all of the methods. You do not have to create an
object or use the object method syntax. You can use each of them independently as if they
were in a package named *perlish_util_udt*.

Example 1(static):
```sql
    SELECT perlish_util_udt.join( 
                perlish_util_udt.sort( 
                        arr_varchar2_udt('one', 'two', 'three', 'four') 
                ), 
                ', ' 
           ) 
    FROM dual;
    -- Or
    SELECT perlish_util_udt.join( 
                perlish_util_udt.sort( 
                    perlish_util_udt.split_csv('one, two, three, four') 
                ), ', ' 
            ) 
    FROM dual;
```
Output:

    "four, one, three, two"

Example 2(static):
```sql
    SELECT perlish_util_udt.join( 
                perlish_util_udt.map('t.$_ = q.$_'
                                    , arr_varchar2_udt('id', 'type')
                )
                , ' AND '
           )
    FROM dual;
```
Output:

    "t.id = q.id AND t.type = q.type"

### Type Specification

```sql
CREATE OR REPLACE TYPE perlish_util_udt AUTHID CURRENT_USER AS OBJECT (
    arr     arr_varchar2_udt

    /* default construtor Oracle provides for reee
    ,CONSTRUCTOR FUNCTION perlish_util_udt(
        p_arr    arr_varchar2_udt DEFAULT NULL
    ) RETURN SELF AS RESULT
    */
    ,CONSTRUCTOR FUNCTION perlish_util_udt(
        p_csv   VARCHAR2
    ) RETURN SELF AS RESULT
    -- all are callable in a chain if they return perlish_util_udt; otherwise must be end of chain
    ,MEMBER FUNCTION get RETURN arr_varchar2_udt
    -- get a collection element
    ,MEMBER FUNCTION get(
        p_i             NUMBER
    ) RETURN VARCHAR2
    ,STATIC FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_arr          arr_varchar2_udt
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- In addition to replacing $_, we had coded replacement of $##index_val##. Do not change
        -- p_ to $# or $## and expect to also use $##index_val##
    ) RETURN arr_varchar2_udt
    ,MEMBER FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_perlish_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN perlish_util_udt
    -- combines elements of 2 arrays based on p_expr and returns a new array
    ,STATIC FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_a        arr_varchar2_udt
        ,p_arr_b        arr_varchar2_udt
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
    ) RETURN arr_varchar2_udt
    ,MEMBER FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_b        arr_varchar2_udt
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
        -- example: v_arr := v_perlish_util_udt(v_arr).combine(q'['$_a_' AS $_b_]', v_second_array);
    ) RETURN perlish_util_udt
    -- join the elements into a string with a separator between them
    ,STATIC FUNCTION join(
        p_arr           arr_varchar2_udt
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    ,MEMBER FUNCTION join(
        p_separator     VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    -- yes these are ridiculous, but I want it
    ,STATIC FUNCTION sort(
        p_arr           arr_varchar2_udt
        ,p_descending   VARCHAR2 DEFAULT 'N'
    ) RETURN arr_varchar2_udt
    ,MEMBER FUNCTION sort(
        p_descending    VARCHAR2 DEFAULT 'N'
    ) RETURN perlish_util_udt
    --
    -- these are really standalone but this was a good place to stash them
    --
    ,STATIC FUNCTION transform_perl_regexp(p_re VARCHAR2)
	RETURN VARCHAR2 DETERMINISTIC

    ,STATIC FUNCTION split_csv (
	     p_s            VARCHAR2
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	) RETURN arr_varchar2_udt DETERMINISTIC

    ,STATIC FUNCTION split_clob_to_lines(p_clob CLOB)
    RETURN arr_varchar2_udt DETERMINISTIC

    ,STATIC PROCEDURE create_ptt_csv (
         -- creates private temporary table ora$ptt_csv with columns named in first row of data case preserved.
         -- All fields are varchar2(4000)
	     p_clob         CLOB
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	)
);
```
### CONSTRUCTOR perlish_util_udt

You can call the default constructor with an *arr_varchar2_udt* collection, or you can call
the custom constructor that takes a VARCHAR2 parameter which will be split on commas by *split_csv*.

### join

The array elements are joined together with a comma separator (or value you provide) returning a single string.
It works pretty much the same as Perl *join*.

You could do the same thing using *LISTAGG* in a SQL statement.

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    v1  VARCHAR2(4000);
BEGIN
    SELECT LISTAGG(column_value,';') INTO v1 FROM TABLE(a1);
    DBMS_OUTPUT.put_line(v1);
END;
```
Output:

    "abc;def"

Contrast that with the following and consider you could chain additional methods if needed.

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    v1  VARCHAR2(4000);
BEGIN
    v1 := perlish_util_udt(a1).join(';');
    DBMS_OUTPUT.put_line(v1);
    -- or --
    v1 := perlish_util_udt.join(a1, ';');
    DBMS_OUTPUT.put_line(v1);
END;
```
### sort

I almost didn't provide this but the fact that you have to reach out to the SQL engine
to do a sort in PL/SQL is sort of annoying (you decide whether the pun is  intended). 
It calls the SQL engine to sort the incoming list and returns a new
*perlish_util_udt* object with the sorted results.

The traditional way:

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    a2  arr_varchar2_udt;
BEGIN
    SELECT column_value BULK COLLECT INTO a2 
    FROM TABLE(a1)
    ORDER BY column_value
    ;
END;
```

The perlish way:

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    a2  arr_varchar2_udt;
BEGIN
    a2 := perlish_util_udt(a1).sort().get();
    -- or --
    a2 := perlish_util_udt.sort(a1);
END;
```
### map

The list elements are transformed by replacing the token '$\_'
with the each list element as many times
as it appears in the *p_expr* string. 

Likewise, if the string '$##index_val##' occurs in the string, it is replaced with the array
index value.

Note that this is just an expression version of the Perl *map*
functionality. We are not doing an anonymous block or anything really fancy. We could, but I do
not think it would be a good idea. Keep your expectations low.

It returns a new *perlish_util_udt* object with the transformed elements.

Note that if you are going to do both *map* and *join*, you could use *LISTAGG* in a SQL statement
to accomplish it. 

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    v1  VARCHAR2(4000);
BEGIN
    SELECT LISTAGG('This is the story of '||column_value, ' and ') INTO v1
    FROM TABLE(a1)
    ;
    DBMS_OUTPUT.put_line(v1);

    -- compared to the perlish way
    v1 := perlish_util_udt(a1).map('This is the story of $_').join(' and ');
    DBMS_OUTPUT.put_line(v1);
END;
```

### combine

Not really a Perl thing because in Perl we would build anonymous arrays/hashes on the fly to do it, 
but I often find myself needing to combine elements of two
lists into a new string value list. It works kind of like map 
and kind of like sort does with the $a and $b variables for different elements (well, different
elements in a single list, but hopefully you get the idea). Given an expression:

    '$_a_ combines with $_b_'

and the input list from the object instance plus the input array named *p_arr_b*,
it loops through the elements substituting the value from the object instance array
whereever '$\_a\_' occurs in the string, and the value from the array named *p_arr_b*
wherever '$\_b\_' occurs in the string. The result is stuffed into the return array
at the same index. You can use different placeholders than '$\_a\_' by specifying 
the placholder strings in the arguments *p_a* and *p_b*.

It returns a new *perlish_util_udt* object with the transformed/combined elements.

Example:

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc','def');
    a2  arr_varchar2_udt := arr_varchar2_udt('xyz','uvw');
    a3  arr_varchar2_udt;
BEGIN
    a3 := perlish_util_udt(a1).combine('$_a_ combines with $_b_', a2).get;
    -- or --
    a3 := perlish_util_udt.combine('$_a_ combines with $_b_', a1, a2);

END;
```

For our example if the first element of our object array was 'abc'
and the first element of *p_arr_b* was 'xyz' we would get

    'abc combines with xyz'

in the first element of the returned array object. Contrast with the SQL way to do the same thing.

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc','def');
    a2  arr_varchar2_udt := arr_varchar2_udt('xyz','uvw');
    a3  arr_varchar2_udt;
BEGIN
    WITH a1 AS (
        SELECT rownum AS rn1, column_value AS v1
        FROM TABLE(a1)
    ), a2 AS (
        SELECT rownum AS rn2, column_value AS v2
        FROM TABLE(a2)
    )
    SELECT v1||' combines with '||v2 BULK COLLECT INTO a3
    FROM a1
    INNER JOIN a2
        ON rn2 = rn1
    ORDER BY rn1
    ;
    FOR i IN 1..a3.COUNT
    LOOP
        DBMS_OUTPUT.put_line(a3(i));
    END LOOP;
END;
```
Yeah, nobody would do that.

> The above depends upon an assumption that *rownum* is assigned in the order that elements
appear in the collection. I believe that will be true based on the way it was almost certainly
implemented; however, I cannot find comfirmation
in the documentation and have read Tom Kyte say many times that the only way you can depend
upon the order of rows returned by a SELECT is to use an ORDER BY. This seems safe enough though.
Everybody does it.

More realistically you would write the routine in PL/SQL.
```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc','def');
    a2  arr_varchar2_udt := arr_varchar2_udt('xyz','uvw');
    a3  arr_varchar2_udt;
BEGIN
    a3 := arr_varchar2_udt();
    a3.EXTEND(a1.COUNT);
    FOR i IN 1..a1.COUNT
    LOOP
        a3(i) := a1(i)||' combines with '||a2(i);
    END LOOP;

    FOR i IN 1..a3.COUNT
    LOOP
        DBMS_OUTPUT.put_line(a3(i));
    END LOOP;
END;
```

### get

The method with no arguments returns the collection from the object so you don't need to
put your grubby paws on it directly.

The override method that takes a NUMBER argument returns an element of the collection. Not only does this allow us
to avoid accessing the member attribute directly, it allows us to get a value from the collection in SQL! See
examples from *split_clob_to_lines*.

### transform_perl_regexp

A function to treat the input value as a Perl-style regular expression with
embedded comments and whitespace that must be stripped as if it were used
with 'x' option in Perl. Although Oracle regular expression functions have an 'x'
modifier, it does not handle comments nor can it strip whitespace without removing
newline and tab characters.

Comments are identified by a Posix [:blank:] character (space or tab for practical purposes)
followed by either '#' or '--'. Once that pattern is found on a line, it and all following
charcters up to the end of the line (newline not included) are removed. If you need to use ' #'
or ' --' in your pattern, you will have to find a way to protect it (hint: put either the space
or comment char in a character class).

Following removal of comments, all whitespace (including newline) is removed as would be true for the 'x' modifier.

Finally, *transform_perl_regexp* translates '\t', '\r' and '\n' tokens to the corresponding literal
values (CHR(9), CHR(13), and CHR(10)) (after stripping whitespace!). It will not replace one
of these if the preceding character is a '\\'. That is intended to let you write '\\\n' such that the 
backwack is protected. It isn't clever enough to figure out '\\\\\n'. Tough. Write your own parser.

This means you can write a regular expression that looks like this:

```sql
    v_re := perlish_util_udt.transform_perl_regexp('
(                               -- capture in \1
  (                             -- going to group 0 or more of these things
    [^"\n]+                     -- any number of chars that are not dquote or newline
    |                           
    "                           -- double quoted string start
        (                       -- just grouping. Order of the next set of things matters. Longest first
            ""                  -- literal "" which is a quoted dquoute within dquote string
            |
            \\"                 -- a backwacked dquote (but need to backwack the backwack)
            |
            [^"]                -- any character not the above two constructs or a dquote
        )*                      -- zero or more of those chars or constructs 
   "                            -- closing dquote
  )*                            -- zero or more strings on a single "line" that could include newline in dquotes
)                               -- end capture \1
(                               -- just grouping 
    $|\n                        -- require match newline or string end 
)                               -- close grouping
');
```
and have the RE that you hand to the Oracle procedure appear as

    (([^"
    ]+|"(""|\\"|[^"])*")*)($|
    )

### split_csv

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
backwacked separators in non-double quoted fields.

See https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml

The problem turned out to be much more complex than I thought when starting the work.
If you like playing with regular expressions, take a gander and tell me if you can 
do better. (really! I like to learn.)

### split_clob_to_lines

The input CLOB is expected to have multiple lines separated by newline (CHR(10)). If you have 
Carriage Returns (CHR(13)) they are included in the resulting rows in the collection, but it is whitespace
and probably won't matter.

The lines can be CSV records meaning they can have double quoted strings that even include newlines.
It will figure them out. The idea is you can have a CLOB like so:

    "abc",123,xyz
    def,456,"ghi"
    lmn,789,opq

and pull the lines out like so:

```sql
select t.column_value as line 
from table(perlish_util_udt.split_clob_to_lines(q'["abc",123,xyz
def,456,"ghi"
lmn,789,opq]'
     ) t
```

The most practical thing to do with them at that point is call *split_csv* on them,
which, conveniently, one of the *perlish_util_udt* constructors will do for us!

```sql
WITH a AS (
    SELECT perlish_util_udt(t.column_value) AS p
    FROM TABLE( perlish_util_udt.split_clob_to_lines(
q'["abc",123,xyz
def,456,"ghi"
lmn,789,opq]'
                                                    )
    ) t
) -- remember you need a table alias to access object methods and attributes
-- thus making the table alias x for a here.
SELECT x.p.get(1) AS col1, x.p.get(2) AS col2, x.p.get(3) AS col3
FROM a x
;
```
This results in:

    "COL1"	"COL2"	"COL3"
    "abc"	"123"	"xyz"
    "def"	"456"	"ghi"
    "lmn"	"789"	"opq"

That requires the person writing the SQL to know how many columns are in the CSV data
and what they are, which really isn't much of a hardship. *csv_to_table* (described next) provides for
named columns, but is probably not necessary for most use cases.

### create_ptt_csv

> NOTE! Private Temporary Tables came available in Oracle 18c. *create_ptt_csv* will not work in prior releases.

*create_ptt_csv* carries the combination of *split_clob_to_lines* and *split_csv* to the next level.

The input clob is expected to contain a set of lines/rows as expected by *split_clob_to_lines* (which it calls).
The first row, however, is expected to contain the column names. These column names are used
to construct an Oracle PRIVATE TEMPORARY TABLE named **ora$ptt_csv** that exists until

- your transaction commits
- you call *create_ptt_csv* again and it drops the PTT before creating it again

All of the fields in the PTT are VARCHAR2(4000).

The data from the rest of the rows/lines is loaded into these columns with NULLS maintained.

An example is the best
explanation:

```sql
BEGIN
    perlish_util_udt.create_ptt_csv('firstcol, secondcol, thirdcol
1, 2, 3
4, 5, 6');
END;
/
SELECT * FROM ora$ptt_csv
;
```
    "firstcol"	"secondcol"	"thirdcol"
    "1"	"2"	"3"
    "4"	"5"	"6"

Or in JSON to make it clear what you are getting:

	{
	  "results" : [
	    {
	      "columns" : [
	        {
	          "name" : "firstcol",
	          "type" : "VARCHAR2"
	        },
	        {
	          "name" : "secondcol",
	          "type" : "VARCHAR2"
	        },
	        {
	          "name" : "thirdcol",
	          "type" : "VARCHAR2"
	        }
	      ],
	      "items" : [
	        {
	          "firstcol" : "1",
	          "secondcol" : "2",
	          "thirdcol" : "3"
	        },
	        {
	          "firstcol" : "4",
	          "secondcol" : "5",
	          "thirdcol" : "6"
	        }
	      ]
	    }
	  ]
	}

#### p_clob

The data is expected to be newline delimited or separated with each line/row containing CSV data. The first row
is expected to contain column names. They must follow Oracle rules for column names. Regardless of your
setting of *p_strip_dquote* for the rest of the data, the column name row is parsed with *p_strip_dquote* set
to 'Y', then the resulting names are enclosed with double quotes. This means your names will have case preserved
and may contain spaces when the PTT is created. You cannot have NULL values in the header row.

Note that if all of your lines do not have at least as many fields as there are column names in the first record,
*create_ptt_csv* will fail on the insert. You may have NULL values in the data (represented by ,,).

#### p_separator

Default is ',', but '|' and ';' are fairly common.

#### p_strip_dquote

You may have a reason to set this to 'N'. You need to understand the implications. It is ignored for the first row.

## csv_to_table

> NOTE: Requires Oracle version 18c or higher

This tool converts CSV records into Oracle columns.

Given a set of rows containing CSV strings, or a CLOB containing multiple lines of CSV strings,
split the records into component column values and return a resultset
that appears as if it was read from 
a table in your schema (or a table to which you have SELECT priv).
A Polymorphic Table Function is employed to do this which is why it requires 18c or higher.

You can either start with a set of CSV strings as rows, or with a CLOB
that contains multiple lines, each of which are a CSV record. Note that 
this is a full blown CSV parser that should handle any records that comply
with RFC4180 (See https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml).

Package *csv_to_table_pkg* specification:

```sql
    FUNCTION ptf(
        p_tab           TABLE
        ,p_columns      VARCHAR2 -- csv list. If the column name is in double quotes, we keep case; otherwise UPPER applied
        ,p_table_name   VARCHAR2
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN TABLE
    PIPELINED ROW POLYMORPHIC USING csv_to_table_pkg
    ;

    -- public type to be returned by split_clob_to_lines PIPE ROW function
    TYPE t_csv_row_rec IS RECORD(
        s   VARCHAR2(4000)  -- the csv row
        ,rn NUMBER          -- line number in the input
    );
    TYPE t_arr_csv_row_rec IS TABLE OF t_csv_row_rec;

    --
    -- split a clob into a row for each line.
    -- Handle case where a "line" can have embedded LF chars per RFC for CSV format
    -- Throw out completely blank lines (but keep track of line number)
    --
    FUNCTION split_clob_to_lines(p_clob CLOB)
    RETURN t_arr_csv_row_rec
    PIPELINED
    ;
```

Given that you can import CSV files to the database in numerous ways including sqlldr,
external tables, Toad, sqlCL, sqlplus and more, the use case for this is limited. If you have 
a clob or a set of CSV row data coming to you in a SQL or PL/SQL program and need to parse
it, then it may be useful. Note that you can parse it into arrays of VARCHAR2 more easily
than what this provides. The conversion to Oracle data types and presentation of the resuts
in a query may be useful. I confess that my original use case for deploying table data
during Continuous Improvement implementations was a bust. The complexity exeeds the benefit.

Example 1:
```sql
create TABLE my_table_name(id number, msg VARCHAR2(1024), dt DATE);

    WITH R AS ( -- convert a CLOB into a set of rows splitting on newline (but protecting CSV protected LF)
        SELECT *
        FROM csv_to_table_pkg.split_clob_to_lines(
-- notice we threw in a blank line in the data
q'!23, "this contains a comma (,)", 06/30/2021
47, "this contains a newline (
)", 01/01/2022

73, and we can have backwacked comma (\,), 12/25/2021
92, what about backwacked dquote >\"<?, 12/28/2021
!'
        )
    ) 
    -- parse the CSV rows and convert them into result set matching column names 
    -- and types from a table we have SELECT priv on
    SELECT *  
    FROM csv_to_table_pkg.ptf(p_tab => R
                            , p_table_name  => 'my_table_name'
                            , p_columns     => 'id, msg, dt', 
                            , p_date_fmt    => 'MM/DD/YYYY'
                            )
    ;

drop table my_table_name;
```

As an alternative if you can get the CSV rows from another source, you do not need split_clob_to_lines. 
For example you could have CSV values in VARCHAR2 column in a configuration table. Here we will demonstrate
with a simple UNION ALL group of records.

```sql
    WITH R AS ( 
                  SELECT '23, "this contains a comma (,)", 06/30/2021' FROM DUAL
        UNION ALL SELECT '47, "this contains a newline (
)", 01/01/2022' FROM DUAL
        UNION ALL SELECT '73, and we can have backwacked comma (\,),' FROM DUAL -- will have NULL date
        UNION ALL SELECT '92, what about backwacked dquote >\"<?, 12/28/2021' FROM DUAL
    ) SELECT *  -- parse the CSV rows and convert them into result set matching column names and types
    FROM csv_to_table_pkg.ptf(p_tab => R
                            , p_table_name  => 'my_table_name'
                            , p_columns     => 'id, msg, dt', 
                            , p_date_fmt    => 'MM/DD/YYYY'
                            )
    ;
```

Example 2 with mixed case column names:
```sql
create table ztest_ptf_tbl(
    id  NUMBER
    ,"String Id"    VARCHAR2(128)
    ,bd             BINARY_DOUBLE
    ,timestamp      TIMESTAMP
    ,"My Date"      DATE
);
--INSERT INTO ztest_ptf_tbl VALUES(1, 'One', 1.1, systimestamp, sysdate);
--INSERT INTO ztest_ptf_tbl VALUES(2, 'Two', 2.2, systimestamp, sysdate);
--INSERT INTO ztest_ptf_tbl VALUES(3, 'Three', 3.3, systimestamp, sysdate);
--COMMIT;

ALTER SESSION SET NLS_DATE_FORMAT='MM/DD/YYYY';
WITH R AS (
    SELECT *
    FROM csv_to_table_pkg.split_clob_to_lines(
q'!
1,"One",1.1,01/02/2022 08.44.12.370423000 AM,01/02/2022
2,"Two",2.2,01/02/2022 08.44.12.477616000 AM,01/02/2022
3,"Three",3.3,01/02/2022 08.44.12.483012000 AM,01/02/2022
!'
    )
) SELECT *
FROM csv_to_table_pkg.ptf(p_tab => R
                            , p_columns => 'Id, "String Id", bd, TimeStamp, "My Date"'
--"ID","String Id","BD","TIMESTAMP","My Date"
                            , p_table_name => 'ztest_ptf_tbl'
                        )
;
DROP TABLE ztest_ptf_tbl;
```

Result exported from sqldeveloper as CSV:

    "ID","String Id","BD","TIMESTAMP","My Date"
    1,"One",1.1,01/02/2022 08.44.12.370423000 AM,01/02/2022
    2,"Two",2.2,01/02/2022 08.44.12.477616000 AM,01/02/2022
    3,"Three",3.3,01/02/2022 08.44.12.483012000 AM,01/02/2022

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
    -- callable in a chain
    ,MEMBER FUNCTION add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    --
    ,MEMBER PROCEDURE add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    --
    -- I never should have differentiated between add_file and add_files plural.
    -- You can use either name. If the file name string contains a comma, it will split it as
    -- multiple files.
    --
    ,MEMBER PROCEDURE add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- comma separated list of file names (or not)
    ,MEMBER PROCEDURE add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    --
    -- names should have dir as first component before slash
    --
    ,MEMBER PROCEDURE add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- these work identically to add_files
    ,MEMBER PROCEDURE add_file(
        p_name          VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_file(
        p_name          VARCHAR2
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
        l_z.add_files('TMPDIR/z.pdf');
        l_z.add_file('TMPDIR/sample.pdf');
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

Unless you are trying to create a generic utility that can handle any query sent its 
way (such as those just mentioned), you almost certainly would be better off using 
native dynamic sql, or at worst, using DBMS_SQL directly. 

DBMS_SQL is an imperfect interface. This is a little better, but only because we are 
returning strings for all values.  The *ANYDATA* interface is grossly inefficient used directly 
inside PL/SQL as each call goes out to the SQL engine, so it is not a viable answer.
It is a hard problem, but an easy button (or at least easier) may be available
with Polymorphic Table Functions come Oracle 18c (I'm still supporting 12c), though that seems 
overly complicated on first blush too. 

The file *app_dbms_sql/test/test1.sql* has an example of using it directly.

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
    --
    -- if you need a column header name that is an oracle reserved word you will not
    -- be able to alias the column in the cursor query with it. You can override
    -- it later with this procedure
    ,FINAL MEMBER PROCEDURE set_column_name(
        SELF IN OUT NOCOPY      app_dbms_sql_udt
        ,p_col_index            INTEGER
        ,p_col_name             VARCHAR2
    )
    ,FINAL MEMBER FUNCTION get_column_names   RETURN arr_varchar2_udt
    ,FINAL MEMBER FUNCTION get_column_types   RETURN arr_varchar2_udt
    -- should only call after completing read of all rows
    ,FINAL MEMBER FUNCTION get_row_count RETURN INTEGER
    -- called from fetch_next_row, subtypes must provide the code
    -- The contract of this method is to set row_index, rows_fetched,
    -- and total_rows_fetched while also storing the bulk collected
    -- values for retrieval.
    ,NOT INSTANTIABLE MEMBER PROCEDURE fetch_rows(
        SELF IN OUT NOCOPY  app_dbms_sql_udt
    )
    -- will call fetch_rows that subtype provides
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
    -- you only need this procedure if you are subtyping app_dbms_sql_str_udt.
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
    -- sets p_arr_clob to NULL when all rows are done
    ,FINAL MEMBER PROCEDURE get_next_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
        ,p_arr_clob OUT NOCOPY arr_clob_udt
    ) 
    --
    -- you have no need to use these two procedures
    -- which are called from get_next_column_values
    ,FINAL MEMBER PROCEDURE get_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
        ,p_arr_clob OUT NOCOPY arr_clob_udt
    ) 
    ,OVERRIDING MEMBER PROCEDURE fetch_rows(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
    )
```
