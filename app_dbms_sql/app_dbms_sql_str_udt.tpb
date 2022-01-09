CREATE OR REPLACE TYPE BODY app_dbms_sql_str_udt AS

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
    CONSTRUCTOR FUNCTION app_dbms_sql_str_udt(
        p_cursor                SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
        ,p_default_num_fmt      VARCHAR2 := 'tm9'
        ,p_default_date_fmt     VARCHAR2 := 'MM/DD/YYYY'
        ,p_default_interval_fmt VARCHAR2 := NULL
    ) RETURN SELF AS RESULT
    IS
    BEGIN
        app_dbms_sql_str_constructor(
            p_cursor, p_bulk_count, p_default_num_fmt, p_default_date_fmt, p_default_interval_fmt
        );
        RETURN;
    END app_dbms_sql_str_udt;

    FINAL MEMBER PROCEDURE app_dbms_sql_str_constructor(
        SELF IN OUT NOCOPY  app_dbms_sql_str_udt
        ,p_cursor               SYS_REFCURSOR
        ,p_bulk_count           INTEGER := 100
        ,p_default_num_fmt      VARCHAR2 := 'tm9'
        ,p_default_date_fmt     VARCHAR2 := 'MM/DD/YYYY'
        ,p_default_interval_fmt VARCHAR2 := NULL
    )
    IS
        v_arr_clob  &&d_arr_clob_udt. := &&d_arr_clob_udt.();
    BEGIN
        SELF.base_constructor(p_cursor, p_bulk_count);
        SELF.default_num_fmt := p_default_num_fmt;
        SELF.default_date_fmt := p_default_date_fmt;
        SELF.default_interval_fmt := p_default_interval_fmt;

        -- we start with these null. They can add them to override defaults with set_formats
        arr_fmts := arr_varchar2_udt();
        arr_fmts.EXTEND(col_cnt);

        -- allocate all of the arrays and array elements one time
        -- buf gets as many rows as we will collect on one bulk
        buf := &&d_arr_arr_clob_udt.();
        buf.EXTEND(p_bulk_count);
        -- our empty row array has entries for each column
        v_arr_clob.EXTEND(col_cnt);
        FOR i IN 1..p_bulk_count
        LOOP
            buf(i) := v_arr_clob; -- allocates empty arrays of col_cnt length
        END LOOP;
    END app_dbms_sql_str_constructor;

    FINAL MEMBER PROCEDURE set_fmt(
        SELF IN OUT NOCOPY  app_dbms_sql_str_udt
        ,p_col_index        BINARY_INTEGER
        ,p_fmt              VARCHAR2
    ) IS
    BEGIN
        IF p_col_index NOT BETWEEN 1 AND col_cnt THEN
            raise_application_error(-20877, 'set_format called with index '||TO_CHAR(p_col_index)||' not between 1 and '||TO_CHAR(col_cnt));
        END IF;
        arr_fmts(p_col_index) := p_fmt;
    END set_fmt;


    OVERRIDING MEMBER PROCEDURE fetch_rows (
        SELF IN OUT NOCOPY  app_dbms_sql_str_udt
    ) IS
        v_ri    BINARY_INTEGER;
      BEGIN
        rows_fetched := DBMS_SQL.fetch_rows(ctx);
        IF rows_fetched != 0 THEN
            row_index := 1;
            v_ri := total_rows_fetched;
            --
            total_rows_fetched := total_rows_fetched + rows_fetched;
            -- for each column grab the bulk fetch set of column values into a local
            -- array. Loop through that set converting each value into a string and store
            -- it into our fetch buffer which is indexed by  row,column where row in this context
            -- is from the set of our current bulk fetch. The index into the local array containing
            -- the values for one column is the actual row count of the sql cursor.
            -- At the end of the loop we will have all of the values for all of the rows in our fetch buffer.
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
                            -- buf(this row from this bulk fetch starting at 1)(this column starting at 1)
                            -- l_t(rows already fetched + this row from this bulk fetch)
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
    END fetch_rows;

    -- convert everything to strings
    FINAL MEMBER PROCEDURE get_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
        ,p_arr_clob OUT NOCOPY &&d_arr_clob_udt.
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

    FINAL MEMBER PROCEDURE get_next_column_values(
        SELF     IN OUT NOCOPY app_dbms_sql_str_udt
        ,p_arr_clob OUT NOCOPY &&d_arr_clob_udt.
    ) 
    IS
    BEGIN
        SELF.fetch_next_row;
        get_column_values(p_arr_clob);
    END get_next_column_values;

END;
/
show errors
