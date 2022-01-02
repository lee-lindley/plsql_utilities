CREATE OR REPLACE TYPE BODY japh_util_udt AS 
    CONSTRUCTOR FUNCTION japh_util_udt(
        p_arr    arr_varchar2_udt DEFAULT NULL
    ) RETURN SELF AS RESULT
    IS
    BEGIN
        IF p_arr IS NOT NULL THEN
            arr := p_arr;
        END IF;
        -- the default it is uninitialized and NULL arr member
        RETURN;
    END;
    CONSTRUCTOR FUNCTION japh_util_udt(
        p_csv   VARCHAR2
    ) RETURN SELF AS RESULT
    IS
    BEGIN
        arr := japh_util_udt.split_csv(p_csv);
        RETURN;
    END;
    -- all are callable in a chain
    MEMBER FUNCTION get 
    RETURN arr_varchar2_udt
    IS
    BEGIN
        RETURN arr;
    END;

    STATIC FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_arr          arr_varchar2_udt
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_japh_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN arr_varchar2_udt
    IS
        v_arr arr_varchar2_udt;
    BEGIN
        IF p_arr IS NOT NULL
        THEN
            v_arr := arr_varchar2_udt();
            v_arr.EXTEND(p_arr.COUNT);
            FOR i IN 1..p_arr.COUNT
            LOOP
                v_arr(i) := REPLACE(p_expr, p_, p_arr(i));
            END LOOP;
        END IF;
        RETURN v_arr;
    END;

    MEMBER FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_japh_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN japh_util_udt
    IS
    BEGIN
        RETURN japh_util_udt( p_arr => japh_util_udt.map(p_arr => arr, p_expr => p_expr, p_ => p_) );
    END;


    STATIC FUNCTION join(
        p_arr   arr_varchar2_udt
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
        RETURN japh_util_udt.join(arr, p_separator); -- can be null
    END;

    STATIC FUNCTION sort(
        p_arr           arr_varchar2_udt
        ,p_descending   VARCHAR2 DEFAULT 'N'
    ) RETURN arr_varchar2_udt
    IS
        v_arr arr_varchar2_udt;
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
    ) RETURN japh_util_udt
    IS
    BEGIN
        RETURN japh_util_udt( p_arr => japh_util_udt.sort(p_arr => arr, p_descending => p_descending) );
    END;
    --

    -- not related to arrays or the object. Just a convenient place to keep it

    STATIC FUNCTION transform_perl_regexp(p_re VARCHAR2)
	RETURN VARCHAR2
	DETERMINISTIC
	IS
	    /*
	        strip comment blocks that start with at least one blank, then
	        '--' or '#', then everything to end of line or string
	    */
	    c_strip_comments_regexp CONSTANT VARCHAR2(32767) := '[[:blank:]](--|#).*($|
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

	STATIC FUNCTION split_csv (
	     p_s            VARCHAR2
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	) RETURN arr_varchar2_udt DETERMINISTIC
	-- when p_s IS NULL, returns initialized collection with COUNT=0
	--
	/*
	
	Treat input string p_s as following the Comma Separated Values (csv) format 
	(not delimited, but separated) and break it into an array of strings (fields) 
	returned to the caller. This is overkill for the most common case
	of simple separated strings that do not contain the separator char and are 
	not quoted, but if they are double quoted fields, this will handle them 
	appropriately including the quoting of " within the field.
	
	We comply with RFC4180 on CSV format (for what it is worth) while also 
	handling the mentioned common variants like backwacked quotes and 
	backwacked separators in non-double quoted fields that Excel produces.
	
	See https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml
	
	*/
	--
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
	/*
	
	USAGE:
	    DECLARE
	        v_arr_varchar2  arr_varchar2_udt;
	        v_s             VARCHAR2(256) 
	            := '123.55,,abcdef,an excel unquoted string with a backwacked comma\, plus more in one field,"a true csv double quoted field with embedded "" and trailing space "';
	    BEGIN
	        v_arr_varchar2 := japh_util_udt.split_csv(v_s);
	        FOR i IN v_arr_varchar2.FIRST..v_arr_varchar2.LAST
	        LOOP
	            DBMS_OUTPUT.put_line(v_arr_varchar2(i));
	        END LOOP;
	    END;
	    --
	    -- or --
	    --
	    SELECT * FROM TABLE(japh_util_udt.split_csv('123.55,,abcdef,an excel unquoted string with a backwacked comma\, plus more in one field,"a true csv double quoted field with embedded "" and trailing space "'
	                                    ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                    )
	                       );
	     -- returns:
	    COLUMN_VALUE
	    123.55
	    (null)
	    abcdef
	    an excel unquoted string with a backwacked comma, plus more in one field
	    "a true csv double quoted field with embedded "" and trailing space "
	
	Note: We are treating the string as SEPARATED, not DELIMITED. That matters 
	        when the last char is a separator char
	
	*/
	IS
	        v_str       VARCHAR2(32767);    -- individual parsed values cannot exceed 4000 chars
	        v_occurence BINARY_INTEGER := 1;
	        v_i         BINARY_INTEGER := 0;
	        v_cnt       BINARY_INTEGER;
	        v_arr       arr_varchar2_udt := arr_varchar2_udt();
	
-- this is what you have to do in Oracle when you are NOT using transform_perl_regexp!!!

	        -- we are going to match multiple times. After each match the position 
	        -- will be after the last separator.
	        v_regexp    VARCHAR2(128) :=
	'\s*'                       -- optional whitespace before anything, or after
	                            -- last delim
	                            --
	||'('                       -- begin capture of \1 which is what we will return.
	                            -- It can be NULL!
	                            --
	||    '"'                       -- one double quote char binding start of the match
	||        '('                       -- just grouping
	--
	-- order of these next things matters. Look for longest one first
	--
	||            '""'                      -- literal "" which is a quoted quote 
	                                        -- within dquote string
	||            '|'                       
	||            '\\"'                     -- Then how about a backwacked double
	                                        -- quote???
	||            '|'
	||            '[^"]'                    -- char that is not a closing quote
	||        ')*'                      -- 0 or more of those chars greedy for
	                                    -- field between quotes
	                                    --
	||    '"'                       -- now the closing dquote 
	||    '|'                       -- if not a double quoted string, try plain one
	--
	-- if the capture is not going to be null or a "*" string, then must start 
	-- with a char that is not a separator or a "
	--
	||    '[^"'||p_separator||']'   -- so one non-sep, non-" character to bind 
	                                -- start of match
	                                --
	||        '('                       -- just grouping
	--
	-- order of these things matters. Look for longest one first
	--
	||            '\\'||p_separator         -- look for a backwacked separator
	||            '|'                       
	||            '[^'||p_separator||']'    -- a char that is not a separator
	||        ')*'                      -- 0 or more of these non-sep, non backwack
	                                    -- sep chars after one starting (bound) a 
	                                    -- char 1 that is neither sep nor "
	                                    --
	||')?'                      -- end capture of our field \1, and we want 0 or 1
	                            -- of them because we can have ',,'
	--
	-- Since we allowed zero matches in the above, regexp_subst can return null
	-- or just spaces in the referenced grouped string \1
	--
	||'('||p_separator||'|$)'   -- now we must find a literal separator or be at 
	                            -- end of string. This separator is included and 
	                            -- consumed at the end of our match, but we do not
	                            -- include it in what we return
	;
	--
	--
	--
	--v_log app_log_udt := app_log_udt('TEST');
	BEGIN
	        IF p_s IS NULL THEN
	            RETURN v_arr; -- will be empty
	        END IF;
	--v_log.log_p(TO_CHAR(REGEXP_COUNT(p_s,v_regexp)));
	        -- since our matched group may be a null string that regexp_substr 
	        -- returns before we are done, we cannot rely on the condition that 
	        -- regexp_substr returns null to know we are done. 
	        -- That is the traditional way to loop using regexp_subst, but that 
	        -- will not work for us. So, we first have to find out how many fields
	        -- we have including null captures and run regexp_substr that many times
	        v_cnt := REGEXP_COUNT(p_s, v_regexp);
	        --
	        -- A "delimited" string, as opposed to a separated string, will end in
	        -- a delimiter char. In other words there is always one "delimiter"
	        -- after every field. But the most common case of CSV is a "separator"
	        -- style which does not have separator at the end, and if we actually
	        -- have a separator at the end of the string, it is because the last
	        -- field value was NULL!!!! In that scenario with the trailing separator
	        -- we want to count that NULL and include it in our array.
	        -- In the case where the last char is not a "separator" char, 
	        -- the regexp will match one last time on the zero-width $. That is an
	        -- oddity of how it is constructed.
	        -- For our purposes of expecting a separated string, not delimited,
	        -- we need to reduce the count by 1 for the case where the last
	        -- character is NOT a separator. 
	        --
	        -- I do not know what to say. I was very dissapointed I could not handle
	        -- all the logic in the regexp, but Oracle regexp are just not as
	        -- powerful as the ones in Perl which have negative/positive lookahead
	        -- and lookbehinds plus the concept of "POS()" so you can match against
	        -- the start of the substr like ^ does for the whole thing. Without
	        -- those features, this was very difficult. It is also possible I am
	        -- missing something important and a regexp expert could do it more
	        -- simply. I would not mind being corrected and shown a better way.
	        --
	        IF SUBSTR(p_s,-1,1) != p_separator THEN -- if last char of string is not the separator
	            v_cnt := v_cnt - 1;
	        END IF;
	
	        FOR v_occurence IN 1..v_cnt
	        LOOP
	            v_str := REGEXP_SUBSTR(
	                    p_s                 -- the string we are parsing
	                    ,v_regexp           -- the regexp we built using the chosen separator (like ',')
	                    ,1                  -- starting at the beginning of the string on the first call
	                    ,v_occurence        -- but on subsequent calls we will get 2nd, then 3rd, etc, match of the pattern
	                    ,''                 -- no regexp modifiers
	                    ,1                  -- we want the \1 grouping match returned, not the entire expression
	            );
	--v_log.log_p(TO_CHAR(v_occurence)||' x'||v_str||'x');
	
	            -- cannot use this test for NULL like the man page for regexp_substr
	            -- shows because our grouped match can be null as a valid value
	            -- while still parsing the string.
	            --EXIT WHEN v_str IS NULL;
	
	            v_str := TRIM(v_str);                               -- if it is a double quoted string, can still have leading/trailing spaces in the value
	            IF v_str IS NOT NULL OR p_keep_nulls = 'Y' THEN     -- otherwise it was an empty string which we discard.
	                -- we WILL add this to the array
	                IF v_str IS NULL THEN
	                    NULL;
	                ELSIF SUBSTR(v_str,1,1) = '"' THEN                 -- it IS a double quoted string
	                    IF p_strip_dquote = 'Y' THEN
	                        -- get rid of starting and ending " char
	                        -- replace any \" or "" pairs with single "
	                        v_str := REGEXP_REPLACE(v_str, 
	                                    '^"|"$'         -- leading " or ending "
	                                    ||'|["\\]'  -- or one of chars " or \
	                                        ||'(")'     -- that is followed by a " and we capture that one in \1
	                                    ,'\1'           -- We put any '"' we captured back without the backwack or " quote
	                                    ,1              -- start at position 1 in v_str
	                                    ,0              -- 0 occurence means replace all of these we find
	                                ); 
	                    END IF;
	                ELSE 
	                        -- not a double quoted string so unbackwack separators inside it. Excel format
	                        v_str := REGEXP_REPLACE(v_str, '\\('||p_separator||')', '\1', 1, 0);
	                END IF; -- end if double quoted string
	                -- Note that if it was an empty double quoted string we are still putting it into the array.
	                -- So, you can still get nulls in the case they are given to you as "" and we stripped the dquotes,
	                -- even if you asked to not keep nulls. Cause an empty string is not NULL. Uggh.
	                v_i := v_i + 1;
	                v_arr.EXTEND;
	                -- this will raise an error if the value is more than 400 chars
	                v_arr(v_i) := v_str;
	            END IF; -- end not an empty string or we want to include NULL
	        END LOOP;
	        RETURN v_arr;
	/*
	Unit tests:
	 select * from TABLE(japh_util_udt.split_csv('"""whatev,er"" and\"", test 2,, abc,'
	                                      ,p_keep_nulls => 'N', p_strip_dquote => 'Y'
	                                   )
	                     );
	
	 -- see impact of trailing comma on number of fields
	 select * from TABLE(japh_util_udt.split_csv('"""whatev,er"" and\"", , test 2,, test3 ,abc,'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
	
	 -- see impact of NO trailing comma on number of fields
	 select * from TABLE(japh_util_udt.split_csv('"""whatev,er"" and\"", , test 2,, test3 ,abc'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
	
	 -- backwacked commas in non quoted strings plus trailing ,
	 select * from TABLE(japh_util_udt.split_csv('"""whatev,e\"r"" and\"", , te\,st 2,, test3\, ,abc,'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
	 SELECT * FROM TABLE(japh_util_udt.split_csv('123.55,,abcdef,an excel unquoted string with a backwacked comma\, plus more in one field,"a true csv double quoted field with embedded "" and trailing space "'
	                                 )
	                    );
	*/
	END --split_csv
	;
END;
/
show errors
