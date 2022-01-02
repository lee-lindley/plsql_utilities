CREATE OR REPLACE PACKAGE csv_to_table_pkg 
AUTHID CURRENT_USER
AS
/*
We provide a mechanism to split CSV string records into component column
values and return a resultset that appears as if it was read from 
a table in your schema (or a table to which you have SELECT priv).
We provide a Polymorphic Table Function for your use to achieve this.

You can either start with a set of CSV strings as rows, or with a CLOB
that contains multiple lines, each of which are a CSV record. Note that 
this is a full blown CSV parser that should handle any records that comply
with RFC4180 (See https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml).

The following example expects a table to exist that provides the column types for the output.
The table is only created as a proxy for one of your tables and is not otherwise used.

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
    ) SELECT *  -- parse the CSV rows and convert them into result set matching column names and types
    FROM csv_to_table_pkg.ptf(p_tab => R
                            , p_table_name  => 'my_table_name'
                            , p_columns     => 'id, msg, dt' 
                            , p_date_fmt    => 'MM/DD/YYYY'
                            )
    ;


As an alternative if you can get the CSV rows from another source, you do not need split_clob_to_lines. 
For example you could have CSV values in VARCHAR2 column in a configuration table. Here we will demonstrate
with a simple UNION ALL group of records.

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

    DROP TABLE my_table_name;

Here is another example showing quoted column names that have mixed case. Note this example depends
on my NLS_DATE_FORMAT setting of 'MM/DD/YYYY' which I do in the script.

whenever sqlerror continue
prompt run these one at a time if you want to see the query result in sqldeveloper
drop table ztest_ptf_tbl;
whenever sqlerror exit failure
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

--
Result exported from sqldeveloper as CSV:
"ID","String Id","BD","TIMESTAMP","My Date"
1,"One",1.1,01/02/2022 08.44.12.370423000 AM,01/02/2022
2,"Two",2.2,01/02/2022 08.44.12.477616000 AM,01/02/2022
3,"Three",3.3,01/02/2022 08.44.12.483012000 AM,01/02/2022


*/

/*
MIT License

Copyright (c) 2022 Lee Lindley

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

    /*
        Expect input data to be rows of CSV lines (VARCHAR2 strings), plus 
        an optional row number column for reporting. The optional column allows us to report
        the rownumber in the original data before it was split into rows and handed to us.
        The reason is that rows may be removed before we get them but we want to report
        on the original line number.

        If the optional rownumber is not included, we will use a running count.

        Each CSV row string will be split into fields which will then populate the output columns
        that will match p_table_name/p_columns names and types. Conversion from string to type
        is part of the magic of this PTF.
    */
    FUNCTION ptf(
        p_tab           TABLE
        -- would like to use COLUMNS pseudo type but it is apparently limited to columns 
        -- that are in the input TABLE argument. When I tried I got 
        -- ORA-62573: new column (ID) is not allowed with describe only polymorphic table function
        -- which apparently means my fetch_rows footprint did not match my describe. I could not make
        -- it work. I also noticed C Saxon used a string for new column arguments in one of his examples,
        -- so there is likely something limiting about COLUMNS type that they must be in the input TABLE.
        ,p_columns      VARCHAR2 -- csv list. If the column name is in double quotes, we keep case; otherwise UPPER applied
        ,p_table_name   VARCHAR2
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN TABLE
    PIPELINED ROW POLYMORPHIC USING csv_to_table_pkg
    ;

    FUNCTION describe(
        p_tab IN OUT    DBMS_TF.TABLE_T
        ,p_columns      VARCHAR2 -- csv list
        ,p_table_name   VARCHAR2
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN DBMS_TF.DESCRIBE_T
    ;
    PROCEDURE fetch_rows(
         p_columns      VARCHAR2 
        ,p_table_name   VARCHAR2
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
        ,p_separator    VARCHAR2 DEFAULT ','
    )
    ;
END csv_to_table_pkg;
/
show errors
