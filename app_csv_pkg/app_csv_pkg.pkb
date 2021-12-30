CREATE OR REPLACE PACKAGE BODY app_csv_pkg AS
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

    FUNCTION get_clob(
        p_src       SYS_REFCURSOR
        ,p_lf_only  VARCHAR2 := 'Y'
    ) RETURN CLOB
    IS
        v_clob          CLOB;
        v_tab_varchar2  DBMS_TF.tab_varchar2_t;
        v_line_end      VARCHAR2(2) := CASE WHEN p_lf_only IN ('Y','y') THEN CHR(10) ELSE CHR(13)||CHR(10) END;
    BEGIN
        LOOP
            FETCH p_src BULK COLLECT INTO v_tab_varchar2 LIMIT 100;
            EXIT WHEN v_tab_varchar2.COUNT = 0;
            FOR i IN 1..v_tab_varchar2.COUNT
            LOOP
                v_clob := v_clob||v_tab_varchar2(i)||v_line_end;
            END LOOP;
        END LOOP;
        RETURN v_clob;
    END get_clob;

    FUNCTION get_clob(
        p_sql       CLOB
        ,p_lf_only  VARCHAR2 := 'Y'
    ) RETURN CLOB
    IS
        v_src       SYS_REFCURSOR;
        v_clob      CLOB;
    BEGIN
        OPEN v_src FOR p_sql;
        v_clob := get_clob(v_src, p_lf_only);
        BEGIN
            CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
        END;
        RETURN v_clob;
    END;

    PROCEDURE write_file(
         p_dir          VARCHAR2
        ,p_file_name    VARCHAR2
        ,p_src          SYS_REFCURSOR
    ) IS
        v_tab_varchar2  DBMS_TF.tab_varchar2_t;
        v_file          UTL_FILE.file_type;
    BEGIN
        v_file := UTL_FILE.fopen(
            filename        => p_file_name
            ,location       => p_dir
            ,open_mode      => 'w'
            ,max_linesize   => 32767
        );
        LOOP
            FETCH p_src BULK COLLECT INTO v_tab_varchar2 LIMIT 100;
            EXIT WHEN v_tab_varchar2.COUNT = 0;
            FOR i IN 1..v_tab_varchar2.COUNT
            LOOP
                UTL_FILE.put_line(v_file, v_tab_varchar2(i));
            END LOOP;
        END LOOP;
        UTL_FILE.fclose(v_file);
    EXCEPTION WHEN OTHERS THEN
        IF UTL_FILE.is_open(v_file)
            THEN UTL_FILE.fclose(v_file);
        END IF;
        RAISE;
    END write_file;

    PROCEDURE write_file(
         p_dir          VARCHAR2
        ,p_file_name    VARCHAR2
        ,p_sql          CLOB
    ) IS
        v_src           SYS_REFCURSOR;
    BEGIN
        OPEN v_src FOR p_sql;
        write_file(
            p_dir           => p_dir
            ,p_file_name    => p_file_name
            ,p_src          => v_src
        );
        BEGIN
            CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
        END;
    END write_file
    ;


    FUNCTION describe(
        p_tab IN OUT            DBMS_TF.TABLE_T
        ,p_header_row           VARCHAR2 := 'Y'
        ,p_separator            VARCHAR2 := ','
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format          VARCHAR2 := NULL
        ,p_interval_format      VARCHAR2 := NULL
    ) RETURN DBMS_TF.DESCRIBE_T
    AS
        v_new_cols  DBMS_TF.columns_new_t;
    BEGIN
        -- stop all input columns from being in the output and create new varchar2 columns that will be in the output
        FOR i IN 1..p_tab.column.COUNT()
        LOOP
            p_tab.column(i).pass_through := FALSE;
            p_tab.column(i).for_read := TRUE;
        END LOOP;
        v_new_cols(1) := DBMS_TF.column_metadata_t(
                                    name    => 'CSV_ROW'
                                    ,type   => DBMS_TF.type_varchar2
                                );

        -- we will use row replication to put a header out on the first row
        RETURN DBMS_TF.describe_t(new_columns => v_new_cols, row_replication => p_header_row IN ('Y','y'));
    END describe
    ;

    PROCEDURE fetch_rows(
         p_header_row           VARCHAR2 := 'Y'
        ,p_separator            VARCHAR2 := ','
        -- you can leave these NULL if you want the default TO_CHAR conversions for your session
        ,p_date_format          VARCHAR2 := NULL
        ,p_interval_format      VARCHAR2 := NULL
    ) AS
        v_env               DBMS_TF.env_t := DBMS_TF.get_env();
        v_rowset            DBMS_TF.row_set_t;  -- the input rowset of CSV rows
        v_row_cnt           BINARY_INTEGER;
        v_col_cnt           BINARY_INTEGER;
        --
        v_val_col           DBMS_TF.tab_varchar2_t;
        v_repfac            DBMS_TF.tab_naturaln_t;
        v_fetch_pass        BINARY_INTEGER := 0;
        v_out_row_i         BINARY_INTEGER := 0;
        -- If the user does not want to change the NLS formats for the session
        -- but has custom coversions for this query, then we will apply them using TO_CHAR
        TYPE t_conv_fmt IS RECORD(
            t   BINARY_INTEGER  -- type
            ,f  VARCHAR2(1024)  -- to_char fmt string
        );
        TYPE t_tab_conv_fmt IS TABLE OF t_conv_fmt INDEX BY BINARY_INTEGER;
        v_conv_fmts         t_tab_conv_fmt;
        --
        FUNCTION apply_cust_conv(
            p_col_index     BINARY_INTEGER
            ,p_row_index    BINARY_INTEGER
        ) RETURN VARCHAR2
        IS
        BEGIN
            RETURN CASE WHEN v_conv_fmts.EXISTS(p_col_index) THEN
                      '"'
                    ||REPLACE(
                        CASE v_conv_fmts(p_col_index).t
                            WHEN DBMS_TF.type_date THEN 
                                TO_CHAR(v_rowset(p_col_index).tab_date(p_row_index), v_conv_fmts(p_col_index).f)
                            WHEN DBMS_TF.type_interval_ym THEN 
                                TO_CHAR(v_rowset(p_col_index).tab_interval_ym(p_row_index), v_conv_fmts(p_col_index).f)
                            WHEN DBMS_TF.type_interval_ds THEN 
                                TO_CHAR(v_rowset(p_col_index).tab_interval_ds(p_row_index), v_conv_fmts(p_col_index).f)
                        END
                        , '"', '\\"'
                      ) -- backwack the dquotes if any
                    ||'"'
                ELSE
                    DBMS_TF.col_to_char(v_rowset(p_col_index), p_row_index)
            END;
        END;
    BEGIN

        IF p_header_row IN ('Y','y') THEN
            -- We need to put out a header row, so we have to engage in replication_factor shenanigans.
            -- This is in case FETCH is called more than once. We get and put to the store
            -- the fetch count.
            -- get does not change value if not found in store so starts with our default 0 on first fetch call
            DBMS_TF.xstore_get('v_fetch_pass', v_fetch_pass); 
--dbms_output.put_line('xstore_get: '||v_fetch_pass);
        ELSE
            v_fetch_pass := 1; -- we do not need a header column. this will double as the flag
        END IF;

        -- get the data for this fetch 
        DBMS_TF.get_row_set(v_rowset, v_row_cnt, v_col_cnt);

        -- set up for custom TO_CHAR conversions if requested for date and/or interval types
        FOR i IN 1..v_col_cnt
        LOOP
            IF (p_date_format IS NOT NULL AND v_env.get_columns(i).type = DBMS_TF.type_date)
            THEN
                v_conv_fmts(i) := t_conv_fmt(DBMS_TF.type_date, p_date_format);
            ELSIF p_interval_format IS NOT NULL 
                AND v_env.get_columns(i).type IN (DBMS_TF.type_interval_ym, DBMS_TF.type_interval_ds) 
            THEN
                v_conv_fmts(i) := t_conv_fmt(v_env.get_columns(i).type, p_interval_format);
            END IF;
        END LOOP;

--dbms_output.put_line('fetched v_row_cnt='||v_row_cnt||', v_col_cnt='||v_col_cnt);
        IF v_fetch_pass = 0 THEN -- this is first pass and we need header row
            -- the first row of our output will get a header row plus the data row
            v_repfac(1) := 2;
            -- the rest of the rows will be 1 to 1 on the replication factor
            FOR i IN 2..v_row_cnt
            LOOP
                v_repfac(i) := 1;
            END LOOP;
            -- these names are already double quoted and Oracle will not allow a doublequote inside a column alias
            v_val_col(1) := v_env.get_columns(1).name;
            FOR j IN 2..v_col_cnt
            LOOP
                v_val_col(1) := v_val_col(1)||p_separator||v_env.get_columns(j).name; --join the column names with ,
            END LOOP;
            v_out_row_i := 1;
--dbms_output.put_line('header row: '||v_val_col(1));
        END IF;
        -- otherwise v_out_row_i is 0

        FOR i IN 1..v_row_cnt
        LOOP
            v_out_row_i := v_out_row_i + 1;
            -- concatenate the string representations of columns with ',' separator
            -- into a single column for output on this row.
            -- col_to_char() conveniently surrounds the character representation
            -- of non-numeric fields with double quotes. If there is a double quote in
            -- that data it will backwack it. Newlines in the field are passed through unchanged.
            v_val_col(v_out_row_i) := apply_cust_conv(1, i); --DBMS_TF.col_to_char(v_rowset(1), i);
            FOR j IN 2..v_col_cnt
            LOOP
                v_val_col(v_out_row_i) := v_val_col(v_out_row_i)||p_separator||apply_cust_conv(j, i); --DBMS_TF.col_to_char(v_rowset(j), i);
            END LOOP;
        END LOOP;

        IF p_header_row IN ('Y','y') THEN    -- save for possible next fetch call
            IF v_fetch_pass = 0 THEN
                -- only on the first fetch 
                DBMS_TF.row_replication(replication_factor => v_repfac);
            END IF;
            v_fetch_pass := v_fetch_pass + 1;
            DBMS_TF.xstore_set('v_fetch_pass', v_fetch_pass);
        END IF;
        -- otherwies we did not do any replication and will get one for one with input rows

        DBMS_TF.put_col(1, v_val_col);

    END fetch_rows;

END app_csv_pkg;
/
show errors
