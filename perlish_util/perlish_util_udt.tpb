CREATE OR REPLACE TYPE BODY perlish_util_udt AS 
	/*
	MIT License
	
	Copyright (c) 2021,2022 Lee Lindley
	
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
    -- this constructor is provided by Oracle by default
    CONSTRUCTOR FUNCTION perlish_util_udt(
        p_arr    &&d_arr_varchar2_udt.
    ) RETURN SELF AS RESULT
    IS
    BEGIN
        IF p_arr IS NOT NULL THEN
            arr := p_arr;
        END IF;
        RETURN;
    END;
    */
    CONSTRUCTOR FUNCTION perlish_util_udt(
         p_csv              VARCHAR2
        ,p_separator        VARCHAR2    DEFAULT ','
	    ,p_keep_nulls       VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote     VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
        ,p_expected_cnt     NUMBER      DEFAULT 0

    ) RETURN SELF AS RESULT
    IS
    BEGIN
        app_csv_pkg.split_csv(
             po_arr         => arr
            ,p_s            => TO_CLOB(p_csv)
            ,p_separator    => p_separator
	        ,p_keep_nulls   => p_keep_nulls
	        ,p_strip_dquote => p_strip_dquote
            ,p_expected_cnt => p_expected_cnt
        );
        RETURN;
    END;

    CONSTRUCTOR FUNCTION perlish_util_udt(
         p_csv              CLOB
        ,p_separator        VARCHAR2    DEFAULT ','
	    ,p_keep_nulls       VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote     VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
        ,p_expected_cnt     NUMBER      DEFAULT 0

    ) RETURN SELF AS RESULT
    IS
    BEGIN
        app_csv_pkg.split_csv(
             po_arr         => arr
            ,p_s            => p_csv
            ,p_separator    => p_separator
	        ,p_keep_nulls   => p_keep_nulls
	        ,p_strip_dquote => p_strip_dquote
            ,p_expected_cnt => p_expected_cnt
        );
        RETURN;
    END;

    -- all are callable in a chain
    MEMBER FUNCTION get 
    RETURN &&d_arr_varchar2_udt.
    IS
    BEGIN
        RETURN arr;
    END;
    -- get a collection element
    MEMBER FUNCTION get(
        p_i             NUMBER
    ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN arr(p_i); -- if you ask for one we do not have, the collection object will puke
    END;

    STATIC FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_arr          &&d_arr_varchar2_udt.
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- we also provide for '$##index_val##' as the array position integer
        -- example: v_arr := v_perlish_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN &&d_arr_varchar2_udt.
    IS
        v_arr &&d_arr_varchar2_udt.;
    BEGIN
        IF p_arr IS NOT NULL
        THEN
            v_arr := &&d_arr_varchar2_udt.();
            v_arr.EXTEND(p_arr.COUNT);
            FOR i IN 1..p_arr.COUNT
            LOOP
                v_arr(i) := REPLACE(REPLACE(p_expr, p_, p_arr(i)), '$##index_val##', i);
            END LOOP;
        END IF;
        RETURN v_arr;
    END;

    MEMBER FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_perlish_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN perlish_util_udt
    IS
    BEGIN
        RETURN perlish_util_udt( perlish_util_udt.map(p_arr => arr, p_expr => p_expr, p_ => p_) );
    END;

    STATIC FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_a        &&d_arr_varchar2_udt.
        ,p_arr_b        &&d_arr_varchar2_udt.
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
    ) RETURN &&d_arr_varchar2_udt.
    IS
        v_arr &&d_arr_varchar2_udt.;
    BEGIN
        IF (p_arr_a IS NULL AND p_arr_b IS NOT NULL)
            OR (p_arr_b IS NULL AND p_arr_b IS NOT NULL)
            OR (p_arr_a.COUNT() != p_arr_b.COUNT())
        THEN
            raise_application_error(-20111,'perlish_util_udt.combine input arrays were not same size');
        END IF;
        IF p_arr_a IS NOT NULL
        THEN
            v_arr := &&d_arr_varchar2_udt.();
            v_arr.EXTEND(p_arr_a.COUNT);
            FOR i IN 1..p_arr_a.COUNT
            LOOP
                v_arr(i) := REPLACE( REPLACE(p_expr, p_a, p_arr_a(i)), p_b, p_arr_b(i) );
            END LOOP;
        END IF;
        RETURN v_arr;
    END;
    MEMBER FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_b        &&d_arr_varchar2_udt.
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
    ) RETURN perlish_util_udt
    IS
    BEGIN
        RETURN perlish_util_udt(perlish_util_udt.combine(
                                        p_expr      => p_expr
                                        , p_arr_a   => arr
                                        , p_arr_b   => p_arr_b
                                        , p_a       => p_a
                                        , p_b       => p_b
                                )
                );
    END;

    STATIC FUNCTION join(
        p_arr   &&d_arr_varchar2_udt.
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    IS
        v_s     VARCHAR2(32767);
    BEGIN
        IF p_arr IS NOT NULL AND p_arr.COUNT > 0 THEN
            v_s := p_arr(1);
            FOR i IN 2..p_arr.COUNT
            LOOP
                v_s := v_s||p_separator||p_arr(i);
            END LOOP;
        END IF;
        RETURN v_s; -- can be null
    END;

    MEMBER FUNCTION join(
        p_separator    VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN perlish_util_udt.join(arr, p_separator); -- can be null
    END;

    STATIC FUNCTION join2clob(
        p_arr   &&d_arr_varchar2_udt.
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN CLOB
    IS
    BEGIN
        RETURN TO_CLOB( perlish_util_udt.join(p_arr, p_separator) ); -- can be null
    END; --join varchar2

    MEMBER FUNCTION join2clob(
        p_separator    VARCHAR2 DEFAULT ','
    ) RETURN CLOB
    IS
    BEGIN
        RETURN TO_CLOB( perlish_util_udt.join(arr, p_separator) ); -- can be null
    END;


    STATIC FUNCTION sort(
        p_arr           &&d_arr_varchar2_udt.
        ,p_descending   VARCHAR2 DEFAULT 'N'
    ) RETURN &&d_arr_varchar2_udt.
    IS
        v_arr &&d_arr_varchar2_udt.;
    BEGIN
        IF p_descending IN ('Y','y') THEN
            SELECT column_value BULK COLLECT INTO v_arr
            FROM TABLE(p_arr)
            ORDER BY column_value DESC
            ;
        ELSE
            SELECT column_value BULK COLLECT INTO v_arr
            FROM TABLE(p_arr)
            ORDER BY column_value
            ;
        END IF;
        RETURN v_arr;
    END;

    MEMBER FUNCTION sort(
        p_descending    VARCHAR2 DEFAULT 'N'
    ) RETURN perlish_util_udt
    IS
    BEGIN
        RETURN perlish_util_udt( perlish_util_udt.sort(p_arr => arr, p_descending => p_descending) );
    END;
    --

    -- not related to arrays or the object. Just a convenient place to keep it

    STATIC FUNCTION transform_perl_regexp(p_re VARCHAR2)
	RETURN VARCHAR2
	DETERMINISTIC
	IS
    BEGIN
        RETURN TO_CHAR( perlish_util_udt.transform_perl_regexp( TO_CLOB(p_re) ) );
    END; -- transform_perl_regexp varchar2

    STATIC FUNCTION transform_perl_regexp(p_re CLOB)
	RETURN CLOB
	DETERMINISTIC
	IS
	    /*
	        strip comment blocks that start with at least one blank, then
	        '--' or '#', then everything to end of line or string
	    */
	    c_strip_comments_regexp CONSTANT VARCHAR2(30) := '[[:blank:]](--|#).*($|
)';
	BEGIN
	    -- note that \n and \t will be replaced if not preceded by a \
	    -- \\n and \\t will not be replaced. Unfortunately, neither will \\\n or \\\t.
	    -- If you need \\\n, use \\ \n since the space will be removed.
	    -- We are not parsing into tokens, so this is as close as we can get cheaply
	    RETURN 
	        REGEXP_REPLACE(
	          REGEXP_REPLACE(
	            REGEXP_REPLACE(
	              REGEXP_REPLACE(
	                REGEXP_REPLACE(p_re, c_strip_comments_regexp, NULL, 1, 0, 'm') -- strip comments
	                    , '\s+', NULL, 1, 0                 -- strip spaces and newlines too like 'x' modifier
	              ) 
	              , '(^|[^\\])\\t', '\1'||CHR(9), 1, 0    -- replace \t with tab character value so it works like in perl
	            ) 
	            , '(^|[^\\])\\n', '\1'||CHR(10), 1, 0       -- replace \n with newline character value so it works like in perl
	          )
	          , '(^|[^\\])\\r', '\1'||CHR(13), 1, 0         -- replace \r with CR character value so it works like in perl
	        ) 
	    ;
	END; -- transform_perl_regexp

END;
/
show errors
