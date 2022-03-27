CREATE OR REPLACE TYPE perlish_util_udt FORCE 
AS OBJECT (
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
    arr     &&d_arr_varchar2_udt.
--select perlish_util_udt(&&d_arr_varchar2_udt.('one', 'two', 'three', 'four')).sort().join(', ') from dual;
--select perlish_util_udt('one, two, three, four').sort().join(', ') from dual;
    /*
    -- this one is provided by Oracle automatically as the default constructor
    ,CONSTRUCTOR FUNCTION perlish_util_udt(
        p_arr    &&d_arr_varchar2_udt. 
    ) RETURN SELF AS RESULT
    */
    ,CONSTRUCTOR FUNCTION perlish_util_udt(
        p_csv   VARCHAR2
    ) RETURN SELF AS RESULT
    -- all are callable in a chain if they return perlish_util_udt; otherwise must be end of chain
    -- get the object member collection
    ,MEMBER FUNCTION get RETURN &&d_arr_varchar2_udt.
    -- get a collection element
    ,MEMBER FUNCTION get(
        p_i             NUMBER
    ) RETURN VARCHAR2
    ,STATIC FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_arr          &&d_arr_varchar2_udt.
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
    ) RETURN &&d_arr_varchar2_udt.
    ,MEMBER FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_perlish_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN perlish_util_udt
    -- combines elements of 2 arrays based on p_expr and returns a new array
    ,STATIC FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_a        &&d_arr_varchar2_udt.
        ,p_arr_b        &&d_arr_varchar2_udt.
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
    ) RETURN &&d_arr_varchar2_udt.
    ,MEMBER FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_b        &&d_arr_varchar2_udt.
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
        -- example: v_arr := v_perlish_util_udt(v_arr).combine(q'['$_a_' AS $_b_]', v_second_array);
    ) RETURN perlish_util_udt

    -- join the elements into a string with a separator between them
    ,STATIC FUNCTION join(
        p_arr           &&d_arr_varchar2_udt.
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    ,MEMBER FUNCTION join(
        p_separator     VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    ,STATIC FUNCTION join2clob(
        p_arr           &&d_arr_varchar2_udt.
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN CLOB
    ,MEMBER FUNCTION join2clob(
        p_separator     VARCHAR2 DEFAULT ','
    ) RETURN CLOB

    -- yes these are ridiculous, but I want it
    ,STATIC FUNCTION sort(
        p_arr           &&d_arr_varchar2_udt.
        ,p_descending   VARCHAR2 DEFAULT 'N'
    ) RETURN &&d_arr_varchar2_udt.
    ,MEMBER FUNCTION sort(
        p_descending    VARCHAR2 DEFAULT 'N'
    ) RETURN perlish_util_udt
    --
    -- these are really standalone but this was a good place to stash them
    --
    ,STATIC FUNCTION transform_perl_regexp(p_re CLOB)
	RETURN CLOB DETERMINISTIC
    ,STATIC FUNCTION transform_perl_regexp(p_re VARCHAR2)
	RETURN VARCHAR2 DETERMINISTIC

);
/
show errors
