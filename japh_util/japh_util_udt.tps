CREATE OR REPLACE TYPE japh_util_udt AUTHID CURRENT_USER AS OBJECT (
    arr     arr_varchar2_udt
--select japh_util_udt(p_arr => arr_varchar2_udt('one', 'two', 'three', 'four')).sort().join(', ') from dual;
    ,CONSTRUCTOR FUNCTION japh_util_udt(
        p_arr    arr_varchar2_udt DEFAULT NULL
    ) RETURN SELF AS RESULT
    ,CONSTRUCTOR FUNCTION japh_util_udt(
        p_csv   VARCHAR2
    ) RETURN SELF AS RESULT
    -- all are callable in a chain if they return japh_util_udt; otherwise must be end of chain
    ,MEMBER FUNCTION get RETURN arr_varchar2_udt
    ,STATIC FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_arr          arr_varchar2_udt
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_japh_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN arr_varchar2_udt
    ,MEMBER FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_japh_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN japh_util_udt
    -- join the elements into a string with a separator between them
    ,STATIC FUNCTION join(
        p_arr           arr_varchar2_udt
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    ,MEMBER FUNCTION join(
        p_separator     VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    -- yes these are ridiculous, but I want it
    ,STATIC FUNCTION sort(
        p_arr           arr_varchar2_udt
        ,p_descending   VARCHAR2 DEFAULT 'N'
    ) RETURN arr_varchar2_udt
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
	) RETURN arr_varchar2_udt DETERMINISTIC
);
/
show errors
