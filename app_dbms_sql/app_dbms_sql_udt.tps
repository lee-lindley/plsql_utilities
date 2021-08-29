CREATE OR REPLACE TYPE app_dbms_sql_udt AUTHID CURRENT_USER AS OBJECT (
-- https://github.com/lee-lindley/plsql_utilities
/*
MIT License

Copyright (c) 2021 Lee Lindley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions

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
        As of Oracle 18c Polymorphic Table Functions may make this obsolete.
        I don't quite have my head around it, and I'm still working on 12c, 
        so I'm stuck with DBMS_SQL, which is exceedingly clunky.

        given a sys_refcursor of unknown select list, set up to bulk collect the column
        values into arrays, then return each row as an array of strings/clobs
        converted per specification.

        You have no reason to use this object type directly because you can just as easily
        do the conversion in SQL. The object is used by a facility to create CSV rows
        taking care of proper quoting, as well as a facility that creates PDF report files.

        Mainly I got sick of handling the details of DBMS_SQL array fetches which essentially
        require you to know what the columns are because you have to declare variables for
        each column type. This is a nicer interface as long as you want strings.

    */

     ctx                    INTEGER
    ,col_cnt                INTEGER
    ,bulk_cnt               INTEGER
    ,total_rows_fetched     INTEGER
    ,rows_fetched           INTEGER
    ,row_index              INTEGER
    ,col_types              arr_integer_udt
    --,CONSTRUCTOR FUNCTION app_dbms_sql_udt(
    --    p_cursor                SYS_REFCURSOR
    --    ,p_bulk_count           INTEGER := 100
    --) RETURN SELF AS RESULT
    ,FINAL MEMBER PROCEDURE base_constructor(
        SELF IN OUT NOCOPY      app_dbms_sql_udt
        ,p_cursor               SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
    )
    ,FINAL MEMBER FUNCTION get_ctx            RETURN INTEGER
    -- if you want it, you will have to go get it yourself using the ctx from get_ctx
    --,MEMBER FUNCTION get_desc_tab3      RETURN DBMS_SQL.desc_tab3
    ,FINAL MEMBER FUNCTION get_column_names   RETURN arr_varchar2_udt
    ,FINAL MEMBER FUNCTION get_column_types   RETURN arr_integer_udt
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
)
NOT FINAL
NOT INSTANTIABLE
;
/
show errors
