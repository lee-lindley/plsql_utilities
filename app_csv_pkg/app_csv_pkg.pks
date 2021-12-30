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

    --
    -- All non numeric fields will be surrounded with double quotes. Any double quotes in the
    -- data will be backwacked to protect them. Newlines in the data are passed through as is
    -- which might cause issues for some CSV parsers.
    FUNCTION ptf(
        p_tab                   TABLE
        ,p_header_row           VARCHAR2 := 'Y'
        ,p_separator            VARCHAR2 := ','
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format          VARCHAR2 := NULL
        ,p_interval_format      VARCHAR2 := NULL
    ) RETURN TABLE
    PIPELINED ROW POLYMORPHIC USING app_csv_pkg
    ;

    --
    -- These two functions and two procedures expect the cursor to return rows containing a single VARCHAR2 column.
    -- Most often you will use in conjunction with a final WITH clause SELECT * from app_csv_pkg.ptf()
    --
    FUNCTION get_clob(
        p_src       SYS_REFCURSOR
        ,p_lf_only  VARCHAR2 := 'Y'
    ) RETURN CLOB
    ;
    FUNCTION get_clob(
        p_sql       CLOB
        ,p_lf_only  VARCHAR2 := 'Y'
    ) RETURN CLOB
    ;
    PROCEDURE write_file(
         p_dir          VARCHAR2
        ,p_file_name    VARCHAR2
        ,p_src          SYS_REFCURSOR
    );
    PROCEDURE write_file(
         p_dir          VARCHAR2
        ,p_file_name    VARCHAR2
        ,p_sql          CLOB
    );

    -- the describe and fetch procedures are used exclusively by the PTF mechanism. You cannot
    -- call them directly.
    FUNCTION describe(
        p_tab IN OUT    DBMS_TF.TABLE_T
        ,p_header_row           VARCHAR2 := 'Y'
        ,p_separator            VARCHAR2 := ','
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format          VARCHAR2 := NULL
        ,p_interval_format      VARCHAR2 := NULL
    ) RETURN DBMS_TF.DESCRIBE_T
    ;
    PROCEDURE fetch_rows(
         p_header_row           VARCHAR2 := 'Y'
        ,p_separator            VARCHAR2 := ','
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_date_format          VARCHAR2 := NULL
        ,p_interval_format      VARCHAR2 := NULL
    )
    ;


END app_csv_pkg;
/
show errors
