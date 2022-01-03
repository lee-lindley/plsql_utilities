CREATE OR REPLACE TYPE japh_util_udt AUTHID CURRENT_USER AS OBJECT (
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
    arr     &&char_collection_type.
--select japh_util_udt(p_arr => &&char_collection_type.('one', 'two', 'three', 'four')).sort().join(', ') from dual;
--select japh_util_udt('one, two, three, four').sort().join(', ') from dual;
    ,CONSTRUCTOR FUNCTION japh_util_udt(
        p_arr    &&char_collection_type. DEFAULT NULL
    ) RETURN SELF AS RESULT
    ,CONSTRUCTOR FUNCTION japh_util_udt(
        p_csv   VARCHAR2
    ) RETURN SELF AS RESULT
    -- all are callable in a chain if they return japh_util_udt; otherwise must be end of chain
    ,MEMBER FUNCTION get RETURN &&char_collection_type.
    ,STATIC FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_arr          &&char_collection_type.
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_japh_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN &&char_collection_type.
    ,MEMBER FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_japh_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN japh_util_udt
    -- join the elements into a string with a separator between them
    ,STATIC FUNCTION join(
        p_arr           &&char_collection_type.
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    ,MEMBER FUNCTION join(
        p_separator     VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    -- yes these are ridiculous, but I want it
    ,STATIC FUNCTION sort(
        p_arr           &&char_collection_type.
        ,p_descending   VARCHAR2 DEFAULT 'N'
    ) RETURN &&char_collection_type.
    ,MEMBER FUNCTION sort(
        p_descending    VARCHAR2 DEFAULT 'N'
    ) RETURN japh_util_udt
    --
    -- these are really standalone but this was a good place to stash them
    --
    ,STATIC FUNCTION transform_perl_regexp(p_re VARCHAR2)
	RETURN VARCHAR2 DETERMINISTIC

    ,STATIC FUNCTION split_csv (
	     p_s            VARCHAR2
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	) RETURN &&char_collection_type. DETERMINISTIC
);
/
show errors
