CREATE OR REPLACE TYPE BODY app_dbms_sql_udt AS

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

  -- these constants are lifted straight out of dbms_sql. Could use them directly as
  -- they will not change, but I'll use the full DBMS_SQL names just because
  /*
  Varchar2_Type                         constant pls_integer :=   1;
  Number_Type                           constant pls_integer :=   2;
  Long_Type                             constant pls_integer :=   8;
  Rowid_Type                            constant pls_integer :=  11;
  Date_Type                             constant pls_integer :=  12;
  Raw_Type                              constant pls_integer :=  23;
  Long_Raw_Type                         constant pls_integer :=  24;
  Char_Type                             constant pls_integer :=  96;
  Binary_Float_Type                     constant pls_integer := 100;
  Binary_Double_Type                    constant pls_integer := 101;
  MLSLabel_Type                         constant pls_integer := 106;
  User_Defined_Type                     constant pls_integer := 109;
  Ref_Type                              constant pls_integer := 111;
  Clob_Type                             constant pls_integer := 112;
  Blob_Type                             constant pls_integer := 113;
  Bfile_Type                            constant pls_integer := 114;
  Timestamp_Type                        constant pls_integer := 180;
  Timestamp_With_TZ_Type                constant pls_integer := 181;
  Interval_Year_to_Month_Type           constant pls_integer := 182;
  Interval_Day_To_Second_Type           constant pls_integer := 183;
  Urowid_Type                           constant pls_integer := 208;
  Timestamp_With_Local_TZ_type          constant pls_integer := 231;
  */

    /* cannot use package types in udt :(
    MEMBER FUNCTION get_desc_tab3 RETURN DBMS_SQL.desc_tab3
    IS
        v_t         DBMS_SQL.desc_tab3;
        v_col_cnt   INTEGER;
    BEGIN
        DBMS_SQL.describe_columns3(ctx, v_col_cnt, v_t);
        RETURN v_t;
    END;
    */

     FINAL MEMBER PROCEDURE set_column_name(
        SELF IN OUT NOCOPY      app_dbms_sql_udt
        ,p_col_index            INTEGER
        ,p_col_name             VARCHAR2
    ) IS
    BEGIN
        IF p_col_index NOT BETWEEN 1 AND col_cnt THEN
            raise_application_error(-20876, 'set_column_name called with index '||TO_CHAR(p_col_index)||' not between 1 and '||TO_CHAR(col_cnt));
        END IF;
        col_names(p_col_index) := p_col_name;
    END set_column_name;

    FINAL MEMBER FUNCTION get_column_names RETURN arr_varchar2_udt
    IS
    BEGIN
        RETURN col_names;
    END get_column_names;

    FINAL MEMBER FUNCTION get_column_types RETURN arr_integer_udt
    IS
    BEGIN
        RETURN col_types;
    END get_column_types;

    FINAL MEMBER FUNCTION get_ctx RETURN INTEGER
    IS
    BEGIN
        RETURN ctx;
    END get_ctx;

    FINAL MEMBER FUNCTION get_row_count RETURN INTEGER
    IS
    BEGIN
        RETURN total_rows_fetched;
    END get_row_count;

    /*
    CONSTRUCTOR FUNCTION app_dbms_sql_udt(
        p_cursor                SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
    ) RETURN SELF AS RESULT
    IS
    BEGIN
        base_constructor(
            p_cursor, p_bluk_count
        );
        RETURN;
    END app_dbms_sql_udt;
    */

    FINAL MEMBER PROCEDURE base_constructor(
        SELF IN OUT NOCOPY      app_dbms_sql_udt
        ,p_cursor               SYS_REFCURSOR
        ,p_bulk_count           INTEGER
    ) 
    IS
        v_src       SYS_REFCURSOR := p_cursor;
        v_t         DBMS_SQL.desc_tab3;

        e_bfile_table DBMS_SQL.bfile_table;
        e_binary_double_table DBMS_SQL.binary_double_table;
        e_binary_float_table DBMS_SQL.binary_float_table;
        e_blob_table DBMS_SQL.blob_table;
        e_clob_table DBMS_SQL.clob_table;
        e_date_table DBMS_SQL.date_table;
        e_interval_day_to_second_table DBMS_SQL.interval_day_to_second_table;
        e_interval_year_to_month_table DBMS_SQL.interval_year_to_month_table;
        e_number_table DBMS_SQL.number_table;
        e_time_table DBMS_SQL.time_table;
        e_time_with_time_zone_table DBMS_SQL.time_with_time_zone_table;
        e_timestamp_table DBMS_SQL.timestamp_table;
        e_timestamp_w_ltz_table DBMS_SQL.timestamp_with_ltz_table;
        e_timestamp_w_time_zone_table DBMS_SQL.timestamp_with_time_zone_table;
        e_urowid_table DBMS_SQL.urowid_table;
        e_varchar2a DBMS_SQL.varchar2a;

    BEGIN
        bulk_cnt := p_bulk_count;
        total_rows_fetched := 0;
        row_index := -1;
        rows_fetched := -1;

        ctx := DBMS_SQL.to_cursor_number(v_src);
        -- populates attribut col_cnt
        DBMS_SQL.describe_columns3(ctx, col_cnt, v_t);

        col_types   := arr_integer_udt();
        col_types.EXTEND(col_cnt);
        col_names   := arr_varchar2_udt();
        col_names.EXTEND(col_cnt);
        -- have dbms_sql define the bulk column associative arrays
        FOR i IN 1..col_cnt
        LOOP
            col_types(i) := v_t(i).col_type;
            col_names(i) := v_t(i).col_name;
            CASE col_types(i)
                WHEN DBMS_SQL.varchar2_type THEN
                    DBMS_SQL.define_array(ctx, i, e_varchar2a, p_bulk_count, 1);
                WHEN DBMS_SQL.number_type THEN
                    DBMS_SQL.define_array(ctx, i, e_number_table, p_bulk_count, 1);
                WHEN DBMS_SQL.long_type THEN
                    DBMS_SQL.define_array(ctx, i, e_varchar2a, p_bulk_count, 1);
                WHEN DBMS_SQL.rowid_type THEN
                    DBMS_SQL.define_array(ctx, i, e_urowid_table, p_bulk_count, 1);
                WHEN DBMS_SQL.date_type THEN
                    DBMS_SQL.define_array(ctx, i, e_date_table, p_bulk_count, 1);
                WHEN DBMS_SQL.char_type THEN
                    DBMS_SQL.define_array(ctx, i, e_varchar2a, p_bulk_count, 1);
                WHEN DBMS_SQL.binary_float_type THEN
                    DBMS_SQL.define_array(ctx, i, e_binary_float_table, p_bulk_count, 1);
                WHEN DBMS_SQL.binary_double_type THEN
                    DBMS_SQL.define_array(ctx, i, e_binary_double_table, p_bulk_count, 1);
                WHEN DBMS_SQL.clob_type THEN
                    DBMS_SQL.define_array(ctx, i, e_clob_table, p_bulk_count, 1);
                WHEN DBMS_SQL.blob_type THEN
                    DBMS_SQL.define_array(ctx, i, e_blob_table, p_bulk_count, 1);
                WHEN DBMS_SQL.bfile_type THEN
                    DBMS_SQL.define_array(ctx, i, e_bfile_table, p_bulk_count, 1);
                WHEN DBMS_SQL.timestamp_type THEN
                    DBMS_SQL.define_array(ctx, i, e_timestamp_table, p_bulk_count, 1);
                WHEN DBMS_SQL.timestamp_with_local_tz_type THEN
                    DBMS_SQL.define_array(ctx, i, e_timestamp_w_ltz_table, p_bulk_count, 1);
                WHEN DBMS_SQL.timestamp_with_tz_type THEN
                    DBMS_SQL.define_array(ctx, i, e_timestamp_w_time_zone_table, p_bulk_count, 1);
                WHEN DBMS_SQL.interval_year_to_month_type THEN
                    DBMS_SQL.define_array(ctx, i, e_interval_year_to_month_table, p_bulk_count, 1);
                WHEN DBMS_SQL.interval_day_to_second_type THEN
                    DBMS_SQL.define_array(ctx, i, e_interval_day_to_second_table, p_bulk_count, 1);
                WHEN DBMS_SQL.urowid_type THEN
                    DBMS_SQL.define_array(ctx, i, e_urowid_table, p_bulk_count, 1);
                ELSE
                    raise_application_error(-20888, 'type: '||v_t(i).col_type||' is not one app_dbms_sql_udt handles');
            END CASE;
        END LOOP;
    END base_constructor; 

    FINAL MEMBER PROCEDURE fetch_next_row(
        SELF IN OUT NOCOPY  app_dbms_sql_udt
    ) IS
    BEGIN
        IF rows_fetched = -1 THEN -- initial state
            fetch_rows;
            IF rows_fetched = 0 THEN
                DBMS_SQL.close_cursor(ctx);
            END IF;
        ELSIF row_index < rows_fetched THEN
            row_index := row_index + 1;
        ELSE
            IF rows_fetched != bulk_cnt THEN -- last fetch got the last of them
                rows_fetched := 0;
            ELSE
                fetch_rows;
                IF rows_fetched = 0 THEN
                    DBMS_SQL.close_cursor(ctx);
                END IF;
            END IF;
        END IF;
    END fetch_next_row;

END;
/
show errors
