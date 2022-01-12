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

    FUNCTION get_ptf_query_string(
        p_sql                           CLOB
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$', then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) RETURN CLOB
    IS
        v_clob                  CLOB;
    BEGIN
        IF REGEXP_LIKE(p_sql, 'app_csv_pkg.ptf', 'i') THEN
            RETURN p_sql;
        END IF;
        IF REGEXP_LIKE(p_sql, '^\s*with\s', 'i') THEN
            v_clob := REGEXP_SUBSTR(p_sql, '(^.+\))(\s*SELECT\s.+$)', 1, 1, 'in', 1);
            v_clob := v_clob||'
, R_app_csv_pkg_ptf AS (
';
            v_clob := v_clob||REGEXP_SUBSTR(p_sql, '(^.+\))(\s*SELECT\s.+$)', 1, 1, 'in', 2);
            v_clob := v_clob||'
)';
        ELSE
            v_clob := 'WITH R_app_csv_pkg_ptf AS (
'||p_sql||'
)';
        END IF;
        v_clob := v_clob||q'[
    SELECT * FROM app_csv_pkg.ptf(
                        p_tab                           => R_app_csv_pkg_ptf
                        ,p_header_row                   => ']'||p_header_row||q'['
                        ,p_separator                    => ']'||p_separator||q'['
                        ,p_protect_numstr_from_excel    => ]'
                || CASE WHEN p_protect_numstr_from_excel IS NULL THEN 'NULL' ELSE q'[']'||p_protect_numstr_from_excel||q'[']' END
                || q'[
                        ,p_date_format                  => ]'
                || CASE WHEN p_date_format IS NULL THEN 'NULL' ELSE q'[']'||p_date_format||q'[']' END
                || q'[
                        ,p_interval_format              => ]'
                || CASE WHEN p_interval_format IS NULL THEN 'NULL' ELSE q'[']'||p_interval_format||q'[']' END
                ||q'[
                  )]';
        RETURN v_clob;
    END get_ptf_query_string
    ;

    PROCEDURE get_clob(
        p_src               SYS_REFCURSOR
        ,p_clob         OUT CLOB
        ,p_rec_count    OUT NUMBER -- includes header row 
        ,p_lf_only          VARCHAR2 := 'Y'
    )
    IS
        v_tab_varchar2  DBMS_TF.tab_varchar2_t;
        v_line_end      VARCHAR2(2) := CASE WHEN p_lf_only IN ('Y','y') THEN CHR(10) ELSE CHR(13)||CHR(10) END;
    BEGIN
        p_rec_count := 0;
        LOOP
            FETCH p_src BULK COLLECT INTO v_tab_varchar2 LIMIT 100;
            EXIT WHEN v_tab_varchar2.COUNT = 0;
            FOR i IN 1..v_tab_varchar2.COUNT
            LOOP
                p_clob := p_clob||v_tab_varchar2(i)||v_line_end;
            END LOOP;
            p_rec_count := p_rec_count + v_tab_varchar2.COUNT;
        END LOOP;
    END get_clob;

    FUNCTION get_clob(
        p_src       SYS_REFCURSOR
        ,p_lf_only  VARCHAR2 := 'Y'
    ) RETURN CLOB
    IS
        v_clob          CLOB;
        v_x             NUMBER;
    BEGIN
        get_clob(p_src => p_src, p_clob => v_clob, p_rec_count => v_x, p_lf_only => p_lf_only);
        RETURN v_clob;
    END get_clob;

    PROCEDURE get_clob(
        p_sql                           CLOB
        ,p_clob                     OUT CLOB
        ,p_rec_count                OUT NUMBER -- includes header row
        ,p_lf_only                      VARCHAR2 := 'Y'
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    )
    IS
        v_sql       CLOB := get_ptf_query_string(
                                p_sql
                                ,p_header_row
                                ,p_separator
                                ,p_protect_numstr_from_excel
                                ,p_date_format
                                ,p_interval_format
                            );
        v_src       SYS_REFCURSOR;
        ORA62558    EXCEPTION;
        pragma EXCEPTION_INIT(ORA62558, -62558);
    BEGIN
        BEGIN
            OPEN v_src FOR v_sql;
        EXCEPTION WHEN ORA62558 THEN
            raise_application_error(-20001, 'sqlcode: '||sqlcode||' One or more columns in the query not supported. If coming from a view that calculates the date, do CAST(val AS DATE) in the view or your sql to fix it.');
        END;

        get_clob(p_src => v_src, p_clob => p_clob, p_rec_count => p_rec_count, p_lf_only => p_lf_only);
        BEGIN
            CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
        END;
    END;

    FUNCTION get_clob(
        p_sql                           CLOB
        ,p_lf_only                      VARCHAR2 := 'Y'
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) RETURN CLOB
    IS
        v_clob      CLOB;
        v_x         NUMBER;
    BEGIN
        get_clob(p_sql                      => p_sql
            ,p_clob                         => v_clob
            ,p_rec_count                    => v_x
            ,p_lf_only                      => p_lf_only
            ,p_header_row                   => p_header_row
            ,p_separator                    => p_separator
            ,p_protect_numstr_from_excel    => p_protect_numstr_from_excel
            ,p_date_format                  => p_date_format
            ,p_interval_format              => p_interval_format
        );
        RETURN v_clob;
    END;

    PROCEDURE write_file(
         p_dir          VARCHAR2
        ,p_file_name    VARCHAR2
        ,p_src          SYS_REFCURSOR
        ,p_rec_cnt  OUT NUMBER -- includes header row
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
        p_rec_cnt := 0;
        LOOP
            FETCH p_src BULK COLLECT INTO v_tab_varchar2 LIMIT 100;
            EXIT WHEN v_tab_varchar2.COUNT = 0;
            FOR i IN 1..v_tab_varchar2.COUNT
            LOOP
                UTL_FILE.put_line(v_file, v_tab_varchar2(i));
            END LOOP;
            p_rec_cnt := p_rec_cnt + v_tab_varchar2.COUNT;
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
        ,p_src          SYS_REFCURSOR
    ) IS
        v_x             NUMBER;
    BEGIN
        write_file(
            p_dir           => p_dir
            ,p_file_name    => p_file_name
            ,p_src          => p_src
            ,p_rec_cnt      => v_x
        );
    END write_file;

    PROCEDURE write_file(
         p_dir                          VARCHAR2
        ,p_file_name                    VARCHAR2
        ,p_sql                          CLOB
        ,p_rec_cnt                  OUT NUMBER -- includes header row
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) IS
        v_sql       CLOB := get_ptf_query_string(
                                p_sql
                                ,p_header_row
                                ,p_separator
                                ,p_protect_numstr_from_excel
                                ,p_date_format
                                ,p_interval_format
                            );
        v_src           SYS_REFCURSOR;
        ORA62558        EXCEPTION;
        pragma EXCEPTION_INIT(ORA62558, -62558);
    BEGIN
        BEGIN
            OPEN v_src FOR v_sql;
        EXCEPTION WHEN ORA62558 THEN
            raise_application_error(-20001, 'sqlcode: '||sqlcode||' One or more columns in the query not supported. If coming from a view that calculates the date, do CAST(val AS DATE) in the view or your sql to fix it.');
        END;

        write_file(
            p_dir           => p_dir
            ,p_file_name    => p_file_name
            ,p_src          => v_src
            ,p_rec_cnt      => p_rec_cnt
        );
        BEGIN
            CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
        END;
    END write_file
    ;

    PROCEDURE write_file(
         p_dir                          VARCHAR2
        ,p_file_name                    VARCHAR2
        ,p_sql                          CLOB
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) IS
        v_x             NUMBER;
    BEGIN
        write_file(
            p_dir                           => p_dir
            ,p_file_name                    => p_file_name
            ,p_sql                          => p_sql
            ,p_rec_cnt                      => v_x
            ,p_header_row                   => p_header_row
            ,p_separator                    => p_separator
            ,p_protect_numstr_from_excel    => p_protect_numstr_from_excel
            ,p_date_format                  => p_date_format
            ,p_interval_format              => p_interval_format
        );
    END write_file
    ;

    --
    -- The rest of this package body is the guts of the Polymorphic Table Function
    -- from the package specification named "ptf". You do not call these directly.
    -- Only the SQL engine calls them.
    -- 
    FUNCTION describe(
        p_tab IN OUT                    DBMS_TF.TABLE_T
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) RETURN DBMS_TF.DESCRIBE_T
    AS
        v_new_cols              DBMS_TF.columns_new_t;
        bad_header_row_param    EXCEPTION;
        pragma EXCEPTION_INIT(bad_header_row_param, -20399);
    BEGIN
        IF p_header_row IS NULL THEN
            raise_application_error(-20399, q'[app_csv_pkg.ptf was passed a NULL value for p_header_row which must be 'Y' or 'N'. You may have attempted to use a bind variable which does not work for Polymorphic Table Function parameter values.]');
        END IF;
        -- stop all input columns from being in the output
        FOR i IN 1..p_tab.column.COUNT()
        LOOP
            p_tab.column(i).pass_through := FALSE;
            p_tab.column(i).for_read := TRUE;
        END LOOP;
        -- create a single new output column for the CSV row string
        v_new_cols(1) := DBMS_TF.column_metadata_t(
                                    name    => 'CSV_ROW'
                                    ,type   => DBMS_TF.type_varchar2
                                );

        -- we will use row replication to put a header out on the first row if desired
        RETURN DBMS_TF.describe_t(new_columns => v_new_cols, row_replication => p_header_row IN ('Y','y'));
    END describe
    ;

    PROCEDURE fetch_rows(
         p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
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
            v_s VARCHAR2(4000);
        BEGIN
            v_s := CASE WHEN v_conv_fmts.EXISTS(p_col_index) THEN
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
                            , '"', '""'
                        ) -- double the dquotes if any
                        ||'"'
                    WHEN p_protect_numstr_from_excel IN ('Y','y') 
                        AND v_env.get_columns(p_col_index).type = DBMS_TF.type_varchar2
                        AND REGEXP_LIKE(v_rowset(p_col_index).tab_varchar2(p_row_index), '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$')
                        THEN '"="'||TRIM(v_rowset(p_col_index).tab_varchar2(p_row_index))||'""' -- code after this will double up internal "
                                                                                          -- giving "=""123.45""" as excel expects
                    ELSE
                        DBMS_TF.col_to_char(v_rowset(p_col_index), p_row_index)
                END;
            -- numbers are not quoted by default by col_to_char, but if they contain the separator charcter
            -- we need to put them in double quotes.
            IF SUBSTR(v_s,1,1) != '"'  THEN
                IF INSTR(v_s,p_separator) != 0 THEN
                    v_s := '"'||v_s||'"';
                END IF;
            ELSIF INSTR(v_s, '"', 2) != LENGTH(v_s) THEN -- we have embedded dquotes, so double them up
                v_s := '"'||REPLACE(SUBSTR(v_s, 2, LENGTH(v_s) - 2), '"', '""')||'"';
            END IF;
            RETURN v_s;
        END; -- apply_cust_conv

    BEGIN -- start of fetch_rows procedure body

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
