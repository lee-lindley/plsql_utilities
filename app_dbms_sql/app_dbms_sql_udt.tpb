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

    MEMBER FUNCTION get_column_names RETURN arr_varchar2_udt
    IS
        v_a     arr_varchar2_udt := arr_varchar2_udt();
        v_t     DBMS_SQL.desc_tab3;
        v_i     INTEGER;
    BEGIN
        DBMS_SQL.describe_columns3(ctx, v_i, v_t);
        v_a.EXTEND(col_cnt);
        FOR i IN 1..v_a.COUNT
        LOOP
            v_a(i) := v_t(i).col_name;
        END LOOP;
        RETURN v_a;
    END get_column_names;

    MEMBER FUNCTION get_column_types RETURN arr_varchar2_udt
    IS
    BEGIN
        RETURN col_types;
    END get_column_types;

    MEMBER FUNCTION get_ctx RETURN INTEGER
    IS
    BEGIN
        RETURN ctx;
    END;

    MEMBER FUNCTION get_row_count RETURN INTEGER
    IS
    BEGIN
        RETURN total_rows_fetched;
    END;


    CONSTRUCTOR FUNCTION app_dbms_sql_udt(
        p_cursor                SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
        ,p_default_num_fmt      VARCHAR2 := 'tm9'
        ,p_default_date_fmt     VARCHAR2 := 'MM/DD/YYYY'
        ,p_default_interval_fmt VARCHAR2 := NULL
    ) RETURN SELF AS RESULT
    IS
        v_src       SYS_REFCURSOR := p_cursor;
        v_t         DBMS_SQL.desc_tab3;
        v_arr_clob  arr_clob_udt := arr_clob_udt();

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

        -- we start with these null. They can add them to override defaults with set_formats
        arr_fmts    := arr_varchar2_udt(col_cnt);
        arr_fmts.EXTEND(col_cnt);

        -- allocate all of the arrays and array elements one time
        buf := arr_arr_clob_udt();
        buf.EXTEND(p_bulk_count);
        v_arr_clob.EXTEND(col_cnt);
        FOR i IN 1..p_bulk_count
        LOOP
            buf(i) := v_arr_clob; -- allocates empty arrays of col_cnt length
        END LOOP;

        col_types   := arr_varchar2_udt(col_cnt);
        col_types.EXTEND(col_cnt);
        -- have dbms_sql define the bulk column associative arrays
        FOR i IN 1..col_cnt
        LOOP
            col_types(i) := v_t(i).col_type;
            CASE v_t(i).col_type
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

        RETURN;

    END; -- constructor

    MEMBER PROCEDURE set_fmt(
        SELF IN OUT NOCOPY  app_dbms_sql_udt
        ,p_col_index        BINARY_INTEGER
        ,p_fmt              VARCHAR2
    ) IS
    BEGIN
        IF p_col_index NOT BETWEEN 1 AND col_cnt THEN
            raise_application_error(-20877, 'set_format called with index '||TO_CHAR(p_col_index)||' not between 1 and '||TO_CHAR(col_cnt));
        END IF;
        arr_fmts(p_col_index) := p_fmt;
    END;


    MEMBER PROCEDURE fetch_next_row(
        SELF IN OUT NOCOPY  app_dbms_sql_udt
    ) IS

      PROCEDURE fetch_rows IS
        v_ri    BINARY_INTEGER;
      BEGIN
        rows_fetched := DBMS_SQL.fetch_rows(ctx);
        IF rows_fetched != 0 THEN
            row_index := 1;
            v_ri := total_rows_fetched - 1; -- we will be adding the current row_index for this bulk to it
            --
            total_rows_fetched := total_rows_fetched + rows_fetched;
            -- grab this fetch batch into the tables, but first clear out
            -- the existing rows so we do not use too much memory.
            FOR i IN 1..col_cnt
            LOOP
              CASE col_types(i)
                WHEN DBMS_SQL.varchar2_type THEN
                    DECLARE
                        l_t DBMS_SQL.varchar2a;
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := l_t(v_ri + j);
                        END LOOP;
                    END;
                WHEN DBMS_SQL.number_type THEN
                    DECLARE
                        l_t DBMS_SQL.number_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_num_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN LTRIM(TO_CHAR(l_t(v_ri+j)))
                                            ELSE LTRIM(TO_CHAR(l_t(v_ri+j), l_fmt))
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.long_type THEN
                    DECLARE
                        l_t DBMS_SQL.varchar2a;
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := l_t(v_ri+j);
                        END LOOP;
                    END;
                WHEN DBMS_SQL.rowid_type THEN
                    DECLARE
                        l_t DBMS_SQL.urowid_table;
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := TO_CHAR(l_t(v_ri+j));
                        END LOOP;
                    END;
                WHEN DBMS_SQL.date_type THEN
                    DECLARE
                        l_t DBMS_SQL.date_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_date_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN TO_CHAR(l_t(v_ri+j))
                                            ELSE TO_CHAR(l_t(v_ri+j), l_fmt)
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.char_type THEN
                    DECLARE
                        l_t DBMS_SQL.varchar2a;
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := l_t(v_ri+j);
                        END LOOP;
                    END;
                WHEN DBMS_SQL.binary_float_type THEN
                    DECLARE
                        l_t DBMS_SQL.binary_float_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_num_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN LTRIM(TO_CHAR(l_t(v_ri+j)))
                                            ELSE LTRIM(TO_CHAR(l_t(v_ri+j), l_fmt))
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.binary_double_type THEN
                    DECLARE
                        l_t DBMS_SQL.binary_double_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_num_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN LTRIM(TO_CHAR(l_t(v_ri+j)))
                                            ELSE LTRIM(TO_CHAR(l_t(v_ri+j), l_fmt))
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.clob_type THEN
                    DECLARE
                        l_t DBMS_SQL.clob_table;
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := l_t(v_ri+j);
                        END LOOP;
                    END;
                WHEN DBMS_SQL.blob_type THEN
                    FOR j IN 1..rows_fetched
                    LOOP
                        buf(j)(i) := NULL;
                    END LOOP;
                WHEN DBMS_SQL.bfile_type THEN
                    FOR j IN 1..rows_fetched
                    LOOP
                        buf(j)(i) := NULL;
                    END LOOP;
                WHEN DBMS_SQL.timestamp_type THEN
                    DECLARE
                        l_t DBMS_SQL.timestamp_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_date_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN TO_CHAR(l_t(v_ri+j))
                                            ELSE TO_CHAR(l_t(v_ri+j), l_fmt)
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.timestamp_with_local_tz_type THEN
                    DECLARE
                        l_t DBMS_SQL.timestamp_with_ltz_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_date_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN TO_CHAR(l_t(v_ri+j))
                                            ELSE TO_CHAR(l_t(v_ri+j), l_fmt)
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.timestamp_with_tz_type THEN
                    DECLARE
                        l_t DBMS_SQL.timestamp_with_time_zone_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_date_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN TO_CHAR(l_t(v_ri+j))
                                            ELSE TO_CHAR(l_t(v_ri+j), l_fmt)
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.interval_year_to_month_type THEN
                    DECLARE
                        l_t DBMS_SQL.interval_year_to_month_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_interval_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN TO_CHAR(l_t(v_ri+j))
                                            ELSE TO_CHAR(l_t(v_ri+j), l_fmt)
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.interval_day_to_second_type THEN
                    DECLARE
                        l_t DBMS_SQL.interval_day_to_second_table;
                        l_fmt           VARCHAR2(4000) := NVL(arr_fmts(i), default_interval_fmt);
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := CASE WHEN l_fmt IS NULL 
                                            THEN TO_CHAR(l_t(v_ri+j))
                                            ELSE TO_CHAR(l_t(v_ri+j), l_fmt)
                                          END;
                        END LOOP;
                    END;
                WHEN DBMS_SQL.urowid_type THEN
                    DECLARE
                        l_t DBMS_SQL.urowid_table;
                    BEGIN
                        DBMS_SQL.column_value(ctx, i, l_t);
                        FOR j IN 1..rows_fetched
                        LOOP
                            buf(j)(i) := TO_CHAR(l_t(v_ri+j));
                        END LOOP;
                    END;
              END CASE;
            END LOOP;
        END IF;
      END;
    -- start fetch_next_row body
    BEGIN
        IF rows_fetched = -1 THEN -- initial state
            fetch_rows;
        ELSIF row_index < rows_fetched THEN
            row_index := row_index + 1;
        ELSE
            IF rows_fetched != bulk_cnt THEN -- last fetch got the last of them
                rows_fetched := 0;
            ELSE
                fetch_rows;
            END IF;
        END IF;
    END;

    -- convert everything to strings
    MEMBER PROCEDURE get_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_udt
        ,p_arr_clob OUT NOCOPY arr_clob_udt
    ) 
    IS
    BEGIN
        IF rows_fetched > 0 THEN 
            p_arr_clob := buf(row_index);
        ELSIF rows_fetched < 0 THEN
            raise_application_error(-20866, 'get_column_values called before first fetch');
        ELSE
            p_arr_clob := NULL;
        END IF;
    END get_column_values;

    MEMBER PROCEDURE get_next_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_udt
        ,p_arr_clob OUT NOCOPY arr_clob_udt
    ) 
    IS
    BEGIN
        fetch_next_row;
        get_column_values(p_arr_clob);
    END get_next_column_values;

END;
/
show errors
