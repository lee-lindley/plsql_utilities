CREATE OR REPLACE PACKAGE BODY app_dbms_sql 
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

    TYPE t_arr_all_arr IS TABLE OF t_all_arr INDEX BY BINARY_INTEGER;
    -- we can have multiple open queries in the same session. We will save our values specific to the cursor number
    g_hash_ctx    t_arr_all_arr;

    FUNCTION get_all_arr(p_ctx BINARY_INTEGER) RETURN t_all_arr
    IS
    BEGIN
        RETURN g_hash_ctx(p_ctx);
    END get_all_arr;

    FUNCTION get_row_count(p_ctx BINARY_INTEGER) RETURN BINARY_INTEGER
    IS
    BEGIN
        RETURN g_hash_ctx(p_ctx).total_rows_fetched;
    END get_row_count;

    FUNCTION get_desc_tab3(p_ctx BINARY_INTEGER) RETURN DBMS_SQL.desc_tab3
    IS
    BEGIN
        RETURN g_hash_ctx(p_ctx).desc_tab3;
    END get_desc_tab3;

    FUNCTION get_column_names(p_ctx BINARY_INTEGER) RETURN t_arr_varchar2
    IS
        v_a     t_arr_varchar2 := t_arr_varchar2();
        v_t     DBMS_SQL.desc_tab3 := get_desc_tab3(p_ctx);
    BEGIN
        v_a.EXTEND(g_hash_ctx(p_ctx).col_cnt);
        FOR i IN 1..v_a.COUNT
        LOOP
            v_a(i) := v_t(i).col_name;
        END LOOP;
        RETURN v_a;
    END get_column_names;

    FUNCTION convert_cursor(
        p_cursor        SYS_REFCURSOR
        ,p_bulk_count   BINARY_INTEGER := 100
    ) RETURN BINARY_INTEGER
    IS
        v_ctx       BINARY_INTEGER;
        v_src       SYS_REFCURSOR := p_cursor;
        v_r         t_all_arr; -- we will populate this structure then assign it to the global hash

        -- need to assign empty associative arrays for multi-level collection stuff to work
        -- on the column_value clauses later
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
        v_r.bulk_count := p_bulk_count;
        v_r.total_rows_fetched := 0;
        v_r.row_index := -1;
        v_r.rows_fetched := -1;
        v_ctx := DBMS_SQL.to_cursor_number(v_src);
        DBMS_SQL.describe_columns3(v_ctx, v_r.col_cnt, v_r.desc_tab3);
        FOR i IN 1..v_r.col_cnt
        LOOP
            CASE v_r.desc_tab3(i).col_type
                WHEN DBMS_SQL.varchar2_type THEN
                    v_r.a_varchar2a_table(i) := e_varchar2a;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_varchar2a_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.number_type THEN
                    v_r.a_number_table(i) := e_number_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_number_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.long_type THEN
                    v_r.a_varchar2a_table(i) := e_varchar2a;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_varchar2a_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.rowid_type THEN
                    v_r.a_urowid_table(i) := e_urowid_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_urowid_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.date_type THEN
                    v_r.a_date_table(i) := e_date_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_date_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.char_type THEN
                    v_r.a_varchar2a_table(i) := e_varchar2a;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_varchar2a_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.binary_float_type THEN
                    v_r.a_binary_float_table(i) := e_binary_float_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_binary_float_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.binary_double_type THEN
                    v_r.a_binary_double_table(i) := e_binary_double_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_binary_double_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.clob_type THEN
                    v_r.a_clob_table(i) := e_clob_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_clob_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.blob_type THEN
                    v_r.a_blob_table(i) := e_blob_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_blob_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.bfile_type THEN
                    v_r.a_bfile_table(i) := e_bfile_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_bfile_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.timestamp_type THEN
                    v_r.a_timestamp_table(i) := e_timestamp_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_timestamp_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.timestamp_with_local_tz_type THEN
                    v_r.a_timestamp_w_ltz_table(i) := e_timestamp_w_ltz_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_timestamp_w_ltz_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.timestamp_with_tz_type THEN
                    v_r.a_timestamp_w_time_zone_table(i) := e_timestamp_w_time_zone_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_timestamp_w_time_zone_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.interval_year_to_month_type THEN
                    v_r.a_interval_year_to_month_table(i) := e_interval_year_to_month_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_interval_year_to_month_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.interval_day_to_second_type THEN
                    v_r.a_interval_day_to_second_table(i) := e_interval_day_to_second_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_interval_day_to_second_table(i), p_bulk_count, 1);
                WHEN DBMS_SQL.urowid_type THEN
                    v_r.a_urowid_table(i) := e_urowid_table;
                    DBMS_SQL.define_array(v_ctx, i, v_r.a_urowid_table(i), p_bulk_count, 1);
            END CASE;
        END LOOP;

        -- save this context
        g_hash_ctx(v_ctx) := v_r;
        RETURN v_ctx;
    END convert_cursor;

    PROCEDURE close_cursor(
        p_ctx IN OUT BINARY_INTEGER
    ) IS
    BEGIN
        IF p_ctx IS NOT NULL THEN 
            g_hash_ctx.DELETE(p_ctx);
            IF DBMS_SQL.IS_OPEN(p_ctx) THEN
                DBMS_SQL.close_cursor(p_ctx); -- also nulls out p_ctx
            ELSE
                p_ctx := NULL;
            END IF;
        END IF;
    END close_cursor;

    FUNCTION fetch_next_row(p_ctx BINARY_INTEGER) RETURN BINARY_INTEGER
    IS

      PROCEDURE fetch_rows IS
      BEGIN
        g_hash_ctx(p_ctx).rows_fetched := DBMS_SQL.fetch_rows(p_ctx);
        IF g_hash_ctx(p_ctx).rows_fetched = 0 THEN
            g_hash_ctx(p_ctx).row_index := 0; -- flag to fetch_next_row
        ELSE
            g_hash_ctx(p_ctx).total_rows_fetched := g_hash_ctx(p_ctx).total_rows_fetched + g_hash_ctx(p_ctx).rows_fetched;
            g_hash_ctx(p_ctx).row_index := 1;
            -- grab this fetch batch into the tables, but first clear out
            -- the existing rows so we do not use too much memory.
            FOR i IN 1..g_hash_ctx(p_ctx).col_cnt
            LOOP
              CASE g_hash_ctx(p_ctx).desc_tab3(i).col_type
                WHEN DBMS_SQL.varchar2_type THEN
                    g_hash_ctx(p_ctx).a_varchar2a_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_varchar2a_table(i));
                WHEN DBMS_SQL.number_type THEN
                    g_hash_ctx(p_ctx).a_number_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_number_table(i));
                WHEN DBMS_SQL.long_type THEN
                    g_hash_ctx(p_ctx).a_varchar2a_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_varchar2a_table(i));
                WHEN DBMS_SQL.rowid_type THEN
                    g_hash_ctx(p_ctx).a_urowid_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_urowid_table(i));
                WHEN DBMS_SQL.date_type THEN
                    g_hash_ctx(p_ctx).a_date_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_date_table(i));
                WHEN DBMS_SQL.char_type THEN
                    g_hash_ctx(p_ctx).a_varchar2a_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_varchar2a_table(i));
                WHEN DBMS_SQL.binary_float_type THEN
                    g_hash_ctx(p_ctx).a_binary_float_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_binary_float_table(i));
                WHEN DBMS_SQL.binary_double_type THEN
                    g_hash_ctx(p_ctx).a_binary_double_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_binary_double_table(i));
                WHEN DBMS_SQL.clob_type THEN
                    g_hash_ctx(p_ctx).a_clob_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_clob_table(i));
                WHEN DBMS_SQL.blob_type THEN
                    g_hash_ctx(p_ctx).a_blob_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_blob_table(i));
                WHEN DBMS_SQL.bfile_type THEN
                    g_hash_ctx(p_ctx).a_bfile_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_bfile_table(i));
                WHEN DBMS_SQL.timestamp_type THEN
                    g_hash_ctx(p_ctx).a_timestamp_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_timestamp_table(i));
                WHEN DBMS_SQL.timestamp_with_local_tz_type THEN
                    g_hash_ctx(p_ctx).a_timestamp_w_ltz_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_timestamp_w_ltz_table(i));
                WHEN DBMS_SQL.timestamp_with_tz_type THEN
                    g_hash_ctx(p_ctx).a_timestamp_w_time_zone_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_timestamp_w_time_zone_table(i));
                WHEN DBMS_SQL.interval_year_to_month_type THEN
                    g_hash_ctx(p_ctx).a_interval_year_to_month_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_interval_year_to_month_table(i));
                WHEN DBMS_SQL.interval_day_to_second_type THEN
                    g_hash_ctx(p_ctx).a_interval_day_to_second_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_interval_day_to_second_table(i));
                WHEN DBMS_SQL.urowid_type THEN
                    g_hash_ctx(p_ctx).a_urowid_table(i).DELETE;
                    DBMS_SQL.column_value(p_ctx, i, g_hash_ctx(p_ctx).a_urowid_table(i));
              END CASE;
            END LOOP;
        END IF;
      END;
    -- start fetch_next_row body
    BEGIN
        IF g_hash_ctx(p_ctx).row_index >= g_hash_ctx(p_ctx).rows_fetched THEN
            IF g_hash_ctx(p_ctx).rows_fetched != g_hash_ctx(p_ctx).bulk_count
                AND g_hash_ctx(p_ctx).rows_fetched != -1 -- initial state
            THEN -- last fetch got the last of them
                RETURN 0;
            ELSE
                fetch_rows;
            END IF;
        ELSE
            g_hash_ctx(p_ctx).row_index := g_hash_ctx(p_ctx).row_index + 1;
        END IF;
        RETURN g_hash_ctx(p_ctx).row_index; -- will be 0 if fetch got none
    END fetch_next_row;

    -- convert everything to strings
    FUNCTION get_column_values(
        p_ctx               BINARY_INTEGER
        ,p_num_format       VARCHAR2 := 'tm9'
        ,p_date_format      VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format  VARCHAR2 := NULL
    ) RETURN t_arr_varchar2
    IS
        v_a         t_arr_varchar2 := t_arr_varchar2();
        v_ri        BINARY_INTEGER;
    BEGIN
        IF g_hash_ctx(p_ctx).row_index = 0 THEN -- last fetch was empty. we are done
            RETURN NULL;
        END IF;
        -- grow our outgoing array to the number of columns we have
        v_a.EXTEND(g_hash_ctx(p_ctx).col_cnt);
        -- we need the index into these bulk collection arrays for this fetch. Remember that
        -- dbms_sql does not assume you have the prior results or not and simply puts the results
        -- into these collections starting where it left off after the last fetch.
        --on first row the math is:  100 - 100 + 1 == 1
        --on second fetch the math is : 200 - 100 + 1 == 101
        v_ri := g_hash_ctx(p_ctx).total_rows_fetched - g_hash_ctx(p_ctx).rows_fetched + g_hash_ctx(p_ctx).row_index;

        FOR i IN 1..g_hash_ctx(p_ctx).col_cnt
        LOOP
              CASE g_hash_ctx(p_ctx).desc_tab3(i).col_type
                WHEN DBMS_SQL.varchar2_type THEN
                    v_a(i) := g_hash_ctx(p_ctx).a_varchar2a_table(i)(v_ri);
                WHEN DBMS_SQL.number_type THEN
                    v_a(i) := CASE WHEN p_num_format IS NULL
                                THEN LTRIM(TO_CHAR(g_hash_ctx(p_ctx).a_number_table(i)(v_ri)))
                                ELSE LTRIM(TO_CHAR(g_hash_ctx(p_ctx).a_number_table(i)(v_ri), p_num_format))
                              END;
                WHEN DBMS_SQL.long_type THEN
                    v_a(i) := g_hash_ctx(p_ctx).a_varchar2a_table(i)(v_ri);
                WHEN DBMS_SQL.rowid_type THEN
                    v_a(i) := g_hash_ctx(p_ctx).a_urowid_table(i)(v_ri);
                WHEN DBMS_SQL.date_type THEN
                    v_a(i) := CASE WHEN p_date_format IS NULL
                                THEN TO_CHAR(g_hash_ctx(p_ctx).a_date_table(i)(v_ri))
                                ELSE TO_CHAR(g_hash_ctx(p_ctx).a_date_table(i)(v_ri), p_date_format)
                              END;
                WHEN DBMS_SQL.char_type THEN
                    v_a(i) := g_hash_ctx(p_ctx).a_varchar2a_table(i)(v_ri);
                WHEN DBMS_SQL.binary_float_type THEN
                    v_a(i) := CASE WHEN p_num_format IS NULL
                                THEN LTRIM(TO_CHAR(g_hash_ctx(p_ctx).a_binary_float_table(i)(v_ri)))
                                ELSE LTRIM(TO_CHAR(g_hash_ctx(p_ctx).a_binary_float_table(i)(v_ri), p_num_format))
                              END;
                WHEN DBMS_SQL.binary_double_type THEN
                    v_a(i) := CASE WHEN p_num_format IS NULL
                                THEN LTRIM(TO_CHAR(g_hash_ctx(p_ctx).a_binary_double_table(i)(v_ri)))
                                ELSE LTRIM(TO_CHAR(g_hash_ctx(p_ctx).a_binary_double_table(i)(v_ri), p_num_format))
                              END;
                WHEN DBMS_SQL.clob_type THEN
                    v_a(i) := g_hash_ctx(p_ctx).a_clob_table(i)(v_ri);
                WHEN DBMS_SQL.blob_type THEN
                    v_a(i) := NULL; --g_hash_ctx(p_ctx).a_blob_table(i)(v_ri);
                WHEN DBMS_SQL.bfile_type THEN
                    v_a(i) := NULL; -- g_hash_ctx(p_ctx).a_bfile_table(i)(v_ri);
                WHEN DBMS_SQL.timestamp_type THEN
                    v_a(i) := CASE WHEN p_date_format IS NULL
                                THEN TO_CHAR(g_hash_ctx(p_ctx).a_timestamp_table(i)(v_ri))
                                ELSE TO_CHAR(g_hash_ctx(p_ctx).a_timestamp_table(i)(v_ri), p_date_format)
                              END;
                WHEN DBMS_SQL.timestamp_with_local_tz_type THEN
                    v_a(i) := CASE WHEN p_date_format IS NULL
                                THEN TO_CHAR(g_hash_ctx(p_ctx).a_timestamp_w_ltz_table(i)(v_ri))
                                ELSE TO_CHAR(g_hash_ctx(p_ctx).a_timestamp_w_ltz_table(i)(v_ri), p_date_format)
                              END;
                WHEN DBMS_SQL.timestamp_with_tz_type THEN
                    v_a(i) := CASE WHEN p_date_format IS NULL
                                THEN TO_CHAR(g_hash_ctx(p_ctx).a_timestamp_w_time_zone_table(i)(v_ri))
                                ELSE TO_CHAR(g_hash_ctx(p_ctx).a_timestamp_w_time_zone_table(i)(v_ri), p_date_format)
                              END;
                WHEN DBMS_SQL.interval_year_to_month_type THEN
                    v_a(i) := CASE WHEN p_interval_format IS NULL
                                THEN TO_CHAR(g_hash_ctx(p_ctx).a_interval_year_to_month_table(i)(v_ri))
                                ELSE TO_CHAR(g_hash_ctx(p_ctx).a_interval_year_to_month_table(i)(v_ri), p_interval_format)
                              END;
                WHEN DBMS_SQL.interval_day_to_second_type THEN
                    v_a(i) := CASE WHEN p_interval_format IS NULL
                                THEN TO_CHAR(g_hash_ctx(p_ctx).a_interval_day_to_second_table(i)(v_ri))
                                ELSE TO_CHAR(g_hash_ctx(p_ctx).a_interval_day_to_second_table(i)(v_ri), p_interval_format)
                              END;
                WHEN DBMS_SQL.urowid_type THEN
                    v_a(i) := g_hash_ctx(p_ctx).a_urowid_table(i)(v_ri);
                ELSE
                    v_a(i) := NULL;
              END CASE;
        END LOOP;
        RETURN v_a;
    END get_column_values;

    FUNCTION get_next_column_values(
        p_ctx               BINARY_INTEGER
        ,p_num_format       VARCHAR2 := 'tm9'
        ,p_date_format      VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format  VARCHAR2 := NULL
    ) RETURN t_arr_varchar2
    IS
        v_i BINARY_INTEGER;
    BEGIN
        v_i := fetch_next_row(p_ctx);
        RETURN CASE WHEN v_i = 0
                    THEN NULL 
                    ELSE get_column_values(p_ctx, p_num_format, p_date_format, p_interval_format) 
               END;
    END get_next_column_values;

END app_dbms_sql;
/
show errors
