CREATE OR REPLACE PACKAGE app_csv_pkg 
AUTHID CURRENT_USER
AS
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

/*

NOTE:

There is a substantial limitation of Polymorphic Table Functions that may make
https://github.com/lee-lindley/app_csv a better choice. Only SCALAR
values are allowed for columns, which sounds innocuous enough, until you understand that
SYSDATE and TO_DATE('20210101','YYYYMMDD') do not fit that definition. If you have those
in your cursor/query/view, you must cast them to DATE for it to work.

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
    FUNCTION split_clob_to_lines(
        p_clob          CLOB
        ,p_max_lines    NUMBER DEFAULT NULL
        ,p_skip_lines   NUMBER DEFAULT NULL
    )
    RETURN t_arr_csv_row_rec
    PIPELINED
    ;
	FUNCTION split_csv (
	     p_s            CLOB
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	) RETURN &&d_arr_varchar2_udt. 
    DETERMINISTIC
    ;

$if DBMS_DB_VERSION.VERSION >= 18 $then

    PROCEDURE create_ptt_csv (
         -- creates private temporary table "ora$ptt_csv" with columns named in first row of data case preserved.
         -- All fields are varchar2(4000)
	     p_clob         CLOB
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	)
    ;

    --
    -- All non numeric fields will be surrounded with double quotes. Any double quotes in the
    -- data will be doubled up to conform to the RFC. Newlines in the data are passed through as is
    -- which might cause issues for some CSV parsers.
    FUNCTION ptf(
        p_tab                           TABLE
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        --
        -- if p_protect_numstr_from_excel==Y and a varchar field looks like a number, 
        -- i.e. matches '^([+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        -- which gets wrapped with dquotes and doubled up inside quotes to "=""00123"""
        -- which makes Excel treat it like a string no matter that it wants to treat any strings that
        -- look like numbers as numbers.
        -- It is gross, but that is what you have to do if you have text fields with leading zeros
        -- or otherwise want to protect strings that look like numbers from Excel auto recognition.
        --
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) RETURN TABLE PIPELINED 
        TABLE -- so can ORDER the input
        --ROW 
        POLYMORPHIC USING app_csv_pkg
    ;


    --
    -- a) If it contains the string app_csv_pkg.ptf (case insensitive match), then it is returned as is. and your 
    --      other arguments are ignored because you should have used them directly in the PTF call.
    -- b) If it does not start with the case insensitive pattern '\s*WITH\s', then we wrap it with a 'WITH R AS (' and
    --      a ') SELECT * FROM app_csv_pkg.ptf(R, __your_parameter_vals__)' before calling it.
    -- c) If it starts with 'WITH', then we search for the final sql clause as '(^.+\))(\s*SELECT\s.+$)' breaking it
    --      into two parts. Between them we add ', R_app_csv_pkg_ptf AS (' and at the end we put
    --      ') SELECT * FROM app_csv_pkg.ptf(R_app_csv_pkg_ptf, __your_parameter_vals__)'
    -- Best thing to do is run your query through the function and see what you get. It has worked in my test cases.
    --
    FUNCTION get_ptf_query_string(
        p_sql                           CLOB
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^[+-]?(\d+[.]?\d*)|([.]\d+)$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) RETURN CLOB
    ;

    --
    -- These two functions and six procedures expect the cursor to return rows containing a single VARCHAR2 column.
    -- Most often you will use in conjunction with a final WITH clause SELECT * from app_csv_pkg.ptf(). If you
    -- are using the p_src(sys_refcursor) version, then it is required that your query conform or is generating
    -- rows independently (though why you would use these methods in that case is a mystery).
    -- If you are using the p_sql(CLOB) versions, the method will transform your SQL using get_ptf_query_string
    -- thus wrapping your query in a call to the PTF so it can generate CSV data
    --
    PROCEDURE get_clob(
        p_src               SYS_REFCURSOR
        ,p_clob         OUT CLOB
        ,p_rec_count    OUT NUMBER -- includes header row
        ,p_lf_only          VARCHAR2 := 'Y'
    );
    FUNCTION get_clob(
        p_src               SYS_REFCURSOR
        ,p_lf_only          VARCHAR2 := 'Y'
    ) RETURN CLOB
    ;
    PROCEDURE get_clob(
        p_sql                           CLOB
        ,p_clob                     OUT CLOB
        ,p_rec_count                OUT NUMBER -- includes header row
        ,p_lf_only                      VARCHAR2 := 'Y'
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^([+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    );
    FUNCTION get_clob(
        p_sql                           CLOB
        ,p_lf_only                      VARCHAR2 := 'Y'
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^([+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) RETURN CLOB
    ;
    PROCEDURE write_file(
         p_dir              VARCHAR2
        ,p_file_name        VARCHAR2
        ,p_src              SYS_REFCURSOR
        ,p_rec_cnt      OUT NUMBER -- includes header row
    );
    PROCEDURE write_file(
         p_dir              VARCHAR2
        ,p_file_name        VARCHAR2
        ,p_src              SYS_REFCURSOR
    );
    PROCEDURE write_file(
         p_dir                          VARCHAR2
        ,p_file_name                    VARCHAR2
        ,p_sql                          CLOB
        ,p_rec_cnt                  OUT NUMBER -- includes header row
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^([+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    );
    PROCEDURE write_file(
         p_dir                          VARCHAR2
        ,p_file_name                    VARCHAR2
        ,p_sql                          CLOB
        -- these only matter if you have the procedure call the PTF for you by not including it in your sql
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^([+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    );

    -- the describe and fetch procedures are used exclusively by the PTF mechanism. You cannot
    -- call them directly.
    FUNCTION describe(
        p_tab IN OUT                    DBMS_TF.TABLE_T
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^([+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) RETURN DBMS_TF.DESCRIBE_T
    ;
    PROCEDURE fetch_rows(
         p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^([+-]?(\d+[.]?\d*)|([.]\d+))$' then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    )
    ;
    -- depends on same date/number defaults on deploy system as on one that creates this
    -- you might wind up messing with the column lists and doing explicit conversions
    FUNCTION gen_deploy_insert(
        p_table_name    VARCHAR2
        ,p_where_clause CLOB DEFAULT NULL
        ,p_schema_name  VARCHAR2 DEFAULT NULL -- defaults to current_schema
    ) RETURN CLOB
    ;
    FUNCTION gen_deploy_merge(
        p_table_name    VARCHAR2
        ,p_key_cols     VARCHAR2 -- CSV list
        ,p_where_clause CLOB DEFAULT NULL
        ,p_schema_name  VARCHAR2 DEFAULT NULL -- defaults to current_schema
    ) RETURN CLOB
    ;

-- end preprocessor directive check for oracle version 18 or greater
$end

END app_csv_pkg;
/
show errors
