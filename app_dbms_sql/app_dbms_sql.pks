CREATE OR REPLACE PACKAGE app_dbms_sql 
AUTHID CURRENT_USER
IS
-- https://github.com/lee-lindley/plsql_utilities
/*
MIT License

Copyright (c) 2021 Lee Lindley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

    /*
        given a sys_refcursor of unknown select list, set up to bulk collect the column
        values into arrays, then return each row as an array of strings
        converted per specification.

        You have no reason to use this package directly because you can just as easily
        do the conversion in SQL. The package is used by a facility to create CSV rows
        taking care of proper quoting as well as a facility that creates PDF report files.

        Mainly I got sick of handling the details of DBMS_SQL array fetches which essentially
        require you to know what the columns are because you have to declare variables for
        each column type.

    */
    TYPE t_arr_varchar2 IS TABLE OF VARCHAR2(32767);

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

    FUNCTION get_desc_tab3(p_ctx BINARY_INTEGER) RETURN DBMS_SQL.desc_tab3;
    FUNCTION get_column_names(p_ctx BINARY_INTEGER) RETURN t_arr_varchar2;
    -- 0 means no more rows; otherwise is the index into the current bulk fetch
    -- not useful other than as a flag
    FUNCTION fetch_next_row(p_ctx BINARY_INTEGER) RETURN BINARY_INTEGER;
    -- will return NULL when no more rows
    FUNCTION get_column_values(
        p_ctx               BINARY_INTEGER
        ,p_num_format       VARCHAR2 := 'tm9'
        ,p_date_format      VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format  VARCHAR2 := NULL
    ) RETURN t_arr_varchar2;
    -- will return NULL when no more rows
    FUNCTION get_next_column_values(
        p_ctx               BINARY_INTEGER
        ,p_num_format       VARCHAR2 := 'tm9'
        ,p_date_format      VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format  VARCHAR2 := NULL
    ) RETURN t_arr_varchar2;

    FUNCTION get_row_count(p_ctx BINARY_INTEGER) RETURN BINARY_INTEGER;

    --
    -- BELOW IS GUTS. 
    --
    -- Not needed for normal use. But if you want to pull out
    -- bfile, blob or clob values, you could with some work.

    -- if you want to muck around in the innards, be my guest. I strongly
    -- recommend against it, but you may have a reason. You could always
    -- fork it on github and add functionality. I'll entertain pull requests.
    --
    -- tables of tables. These will be sparse with the index being the column number.
    -- So if columns 1 and 3 are number columns, arr_number_table(1) and (3)
    -- will hold DBMS_SQL.number_table's. Those are also associative arrays, so
    -- the uncommon syntax to get a value from a variable of one of these types
    -- is varnam(v_i)(v_j)
    --
    TYPE arr_bfile_table IS TABLE OF DBMS_SQL.bfile_table INDEX BY BINARY_INTEGER;
    TYPE arr_binary_double_table IS TABLE OF DBMS_SQL.binary_double_table INDEX BY BINARY_INTEGER;
    TYPE arr_binary_float_table IS TABLE OF DBMS_SQL.binary_float_table INDEX BY BINARY_INTEGER;
    TYPE arr_blob_table IS TABLE OF DBMS_SQL.blob_table INDEX BY BINARY_INTEGER;
    TYPE arr_clob_table IS TABLE OF DBMS_SQL.clob_table INDEX BY BINARY_INTEGER;
    TYPE arr_date_table IS TABLE OF DBMS_SQL.date_table INDEX BY BINARY_INTEGER;
    TYPE arr_interval_day_to_second_table IS TABLE OF DBMS_SQL.interval_day_to_second_table INDEX BY BINARY_INTEGER;
    TYPE arr_interval_year_to_month_table IS TABLE OF DBMS_SQL.interval_year_to_month_table INDEX BY BINARY_INTEGER;
    TYPE arr_number_table IS TABLE OF DBMS_SQL.number_table INDEX BY BINARY_INTEGER;
    TYPE arr_time_table IS TABLE OF DBMS_SQL.time_table INDEX BY BINARY_INTEGER;
    TYPE arr_time_with_time_zone_table IS TABLE OF DBMS_SQL.time_with_time_zone_table INDEX BY BINARY_INTEGER;
    TYPE arr_timestamp_table IS TABLE OF DBMS_SQL.timestamp_table INDEX BY BINARY_INTEGER;
    TYPE arr_timestamp_w_ltz_table IS TABLE OF DBMS_SQL.timestamp_with_ltz_table INDEX BY BINARY_INTEGER;
    TYPE arr_timestamp_w_time_zone_table IS TABLE OF DBMS_SQL.timestamp_with_time_zone_table INDEX BY BINARY_INTEGER;
    TYPE arr_urowid_table IS TABLE OF DBMS_SQL.urowid_table INDEX BY BINARY_INTEGER;
    TYPE arr_varchar2a_table IS TABLE OF DBMS_SQL.varchar2a INDEX BY BINARY_INTEGER;

    -- for each open cursor in the session we can have one of these. It will hold
    -- all the state data about the cursor and the column values from the returned rows.
    -- only the values for the current bulk fetch will be in the tables.
    TYPE t_all_arr IS RECORD(
        desc_tab3                       DBMS_SQL.desc_tab3
        ,col_cnt                        BINARY_INTEGER
        ,bulk_count                     BINARY_INTEGER
        ,total_rows_fetched             BINARY_INTEGER
        ,row_index                      BINARY_INTEGER
        ,rows_fetched                   BINARY_INTEGER
        ,a_bfile_table                  arr_bfile_table
        ,a_binary_double_table          arr_binary_double_table 
        ,a_binary_float_table           arr_binary_float_table 
        ,a_blob_table                   arr_blob_table 
        ,a_clob_table                   arr_clob_table 
        ,a_date_table                   arr_date_table 
        ,a_interval_day_to_second_table arr_interval_day_to_second_table 
        ,a_interval_year_to_month_table arr_interval_year_to_month_table 
        ,a_number_table                 arr_number_table 
        ,a_time_table                   arr_time_table 
        ,a_time_with_time_zone_table    arr_time_with_time_zone_table 
        ,a_timestamp_table              arr_timestamp_table 
        ,a_timestamp_w_ltz_table        arr_timestamp_w_ltz_table 
        ,a_timestamp_w_time_zone_table arr_timestamp_w_time_zone_table 
        ,a_urowid_table                 arr_urowid_table 
        ,a_varchar2a_table              arr_varchar2a_table 
    );


    -- returns the context holder with all the current state. 
    -- actual working context.  I do not know why
    -- you would want to do so, but there it is.
    -- NOTE: it is a copy. I could pass out the entire collection
    -- as an OUT variable with NOCOPY and that works, but individual
    -- records that are members of a collection cannot apparently be passed
    -- as a pointer. They are always copied unless they are also a collection.
    FUNCTION get_all_arr(p_ctx BINARY_INTEGER) RETURN t_all_arr;

END app_dbms_sql;
/
show errors
