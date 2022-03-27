# app_dbms_sql

*app_dbms_sql_udt* is a base type that cannot be instantiated.

*app_dbms_sql_str_udt* is a subtype of *app_dbms_sql_udt*. It can be instantiated, tested
and used standalone or as a supertype.

Given a SYS\_REFCURSOR of unknown select list, *app_dbms_sql_str_udt* sets up to bulk collect the column
values into arrays, then return each row as an array of strings
converted per optional TO\_CHAR conversion specification.

You have no reason to use this package directly because you can just as easily
do the conversion to text in SQL. The type is used by a facility to create CSV rows
(taking care of proper quoting), as well as a facility that creates PDF report files.

Unless you are trying to create a generic utility that can handle any query sent its 
way (such as those just mentioned), you almost certainly would be better off using 
native dynamic sql, or at worst, using DBMS\_SQL directly. 

DBMS\_SQL is an imperfect interface. This is a little better, but only because we are 
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
