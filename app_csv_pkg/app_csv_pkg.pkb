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

    -- split a clob into a row for each line.
    -- Handle case where a "line" can have embedded LF chars per RFC for CSV format
    -- Throw out completely blank lines
    --
    FUNCTION split_clob_to_lines(
        p_clob          CLOB
        ,p_max_lines    NUMBER DEFAULT NULL
        ,p_skip_lines   NUMBER DEFAULT NULL
    )
    RETURN t_arr_csv_row_rec
    PIPELINED
    IS
        v_rc            BINARY_INTEGER := 0;
        v_pos           BINARY_INTEGER;
        v_pos_last      BINARY_INTEGER := 1;
        v_len           BINARY_INTEGER;
        v_row           t_csv_row_rec;

        v_rows_regexp   VARCHAR2(1024) := perlish_util_udt.transform_perl_regexp('
(                               # capture in \1
  (                             # going to group 0 or more of these things
    "                           # double quoted string start
        (                       # just grouping. Order of the next set of things matters. Longest first
            ""                  # literal "" which is a quoted dquoute within dquote string
            |
            \\"                 # a backwacked dquote 
            |
            [^"]                # any single character not the above two multi-char constructs, or a dquote
                                #     Important! This can be embedded newlines too!
        )*                      # zero or more of those chars or constructs 
    "                           # closing dquote
    |                           
    [^"\n\\]+                   # any number of chars that are not dquote, backwack or newline
    |
    (                           # just grouping for repeat
        \\[\n]                  # or a backwacked \n but protect from proceeding backwack so is interpreted by transform_perl_regexp
    )+                          # one or more protected newlines (as if they were in dquoted string)
    |
    (                           # just grouping for repeat
        \\"                     # or a backwacked "
    )+                          # one or more protected "
    |
    \\                          # or a backwack, but do this last as it is the smallest and we do not want
                                #   to consume the backwack before a newline or a dquote
  )*                            # zero or more strings on a single "line" that could include newline in dquotes
                                # or even a backwacked newline
)                               # end capture \1
(                               # just grouping 
    $|\n                        # require match newline or string end 
)                               # close grouping
');
    BEGIN
--DBMS_OUTPUT.put_line('length: '||LENGTH(p_clob));
        LOOP
            -- v_pos is the character position AFTER the match
            v_pos := REGEXP_INSTR(p_clob, v_rows_regexp, v_pos_last, 1, 1);
--DBMS_OUTPUT.put_line('vpos: '||v_pos||' v_pos_last: '||v_pos_last);
            EXIT WHEN v_pos = 0;
            v_rc := v_rc + 1;
            --
            -- Leave the newline out of the string we pipe out for this row
            -- (If there is one. May not be on last line.)
            --
            v_len := (v_pos - v_pos_last) - CASE WHEN SUBSTR(p_clob, v_pos - 1, 1) = CHR(10) THEN 1 ELSE 0 END;
--DBMS_OUTPUT.put_line('v_len: '||v_len);
            IF v_rc <= p_skip_lines THEN
                -- still need to advance the position
                v_pos_last := v_pos;
                CONTINUE;
            END IF;
            IF v_len > 0 THEN
                v_row.rn := v_rc;
                v_row.s := SUBSTR(p_clob, v_pos_last, v_len);
                PIPE ROW(v_row);
            END IF;
            EXIT WHEN v_rc >= p_max_lines 
                OR v_pos_last = v_pos; -- match on end of clob will repeat as it is 0 width
            v_pos_last := v_pos;
        END LOOP;
        RETURN;
    END split_clob_to_lines
    ;
    FUNCTION split_lines_to_fields(
        p_curs          t_curs_csv_row_rec
        ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
        ,p_keep_nulls   VARCHAR2    DEFAULT 'Y'
    ) 
    RETURN t_arr_csv_fields_rec
    PIPELINED
    IS
        v_row       t_csv_fields_rec;
        v_in_row    t_csv_row_rec;
    BEGIN
        LOOP
            FETCH p_curs INTO v_in_row;
            EXIT WHEN p_curs%NOTFOUND;
            v_row.rn := v_in_row.rn;
            v_row.arr := split_csv(v_in_row.s
                                    , p_separator       => p_separator
                                    , p_strip_dquote    => p_strip_dquote
                                    , p_keep_nulls      => p_keep_nulls
            );
            PIPE ROW(v_row);
        END LOOP;
        RETURN;
    END split_lines_to_fields
    ;

	FUNCTION split_csv (
	     p_s            CLOB
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	) RETURN &&d_arr_varchar2_udt. 
    DETERMINISTIC
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
	
	USAGE:
	    DECLARE
	        v_arr_varchar2  &&d_arr_varchar2_udt.;
	        v_s             VARCHAR2(256) 
	            := '123.55,,abcdef,an excel unquoted string with a backwacked comma\, plus more in one field,"a true csv double quoted field with embedded "" and trailing space "';
	    BEGIN
	        v_arr_varchar2 := app_csv_pkg.split_csv(v_s);
	        FOR i IN v_arr_varchar2.FIRST..v_arr_varchar2.LAST
	        LOOP
	            DBMS_OUTPUT.put_line(v_arr_varchar2(i));
	        END LOOP;
	    END;
	    --
	    -- or --
	    --
	    SELECT * FROM TABLE(app_csv_pkg.split_csv('123.55,,abcdef,an excel unquoted string with a backwacked comma\, plus more in one field,"a true csv double quoted field with embedded "" and trailing space "'
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
	        v_arr       &&d_arr_varchar2_udt. := &&d_arr_varchar2_udt.();
	
-- this is what you have to do in Oracle when you are NOT using transform_perl_regexp!!!
-- If I ever have a need to edit and retest it, I'll redo it that way.

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
	                -- this will raise an error if the value is more than 4000 chars
	                v_arr(v_i) := v_str;
	            END IF; -- end not an empty string or we want to include NULL
	        END LOOP;
	        RETURN v_arr;
	/*
	Unit tests:
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,er"" and\"", test 2,, abc,'
	                                      ,p_keep_nulls => 'N', p_strip_dquote => 'Y'
	                                   )
	                     );
	
	 -- see impact of trailing comma on number of fields
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,er"" and\"", , test 2,, test3 ,abc,'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
	
	 -- see impact of NO trailing comma on number of fields
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,er"" and\"", , test 2,, test3 ,abc'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
	
	 -- backwacked commas in non quoted strings plus trailing ,
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,e\"r"" and\"", , te\,st 2,, test3\, ,abc,'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
	 SELECT * FROM TABLE(app_csv_pkg.split_csv('123.55,,abcdef,an excel unquoted string with a backwacked comma\, plus more in one field,"a true csv double quoted field with embedded "" and trailing space "'
	                                 )
	                    );
	*/
	END split_csv
	;



$if DBMS_DB_VERSION.VERSION >= 18 $then
    FUNCTION get_ptf_query_string(
        p_sql                           CLOB
        ,p_header_row                   VARCHAR2 := 'Y'
        ,p_separator                    VARCHAR2 := ','
        -- if Y and a varchar field matches '^(\s*[+-]?(\d+[.]?\d*)|([.]\d+))$', then output '="'||field||'"'
        ,p_protect_numstr_from_excel    VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
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
                        ,p_num_format                   => ]'
                || CASE WHEN p_num_format IS NULL THEN 'NULL' ELSE q'[']'||p_num_format||q'[']' END
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
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    )
    IS
        v_sql       CLOB := get_ptf_query_string(
                                p_sql
                                ,p_header_row
                                ,p_separator
                                ,p_protect_numstr_from_excel
                                ,p_num_format
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
        ,p_num_format                   VARCHAR2 := NULL
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
            ,p_num_format                   => p_num_format
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
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
    ) IS
        v_sql       CLOB := get_ptf_query_string(
                                p_sql
                                ,p_header_row
                                ,p_separator
                                ,p_protect_numstr_from_excel
                                ,p_num_format
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
        ,p_num_format                   VARCHAR2 := NULL
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
            ,p_num_format                   => p_num_format
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
        ,p_num_format                   VARCHAR2 := NULL
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
        ,p_num_format                   VARCHAR2 := NULL
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
                                WHEN DBMS_TF.type_number THEN 
                                    TO_CHAR(v_rowset(p_col_index).tab_number(p_row_index), v_conv_fmts(p_col_index).f)
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
            IF p_date_format IS NOT NULL AND v_env.get_columns(i).type = DBMS_TF.type_date
            THEN
                v_conv_fmts(i) := t_conv_fmt(DBMS_TF.type_date, p_date_format);
            ELSIF p_num_format IS NOT NULL AND v_env.get_columns(i).type = DBMS_TF.type_number
            THEN
                v_conv_fmts(i) := t_conv_fmt(DBMS_TF.type_number, p_num_format);
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

/* This version is faster but unnecessarily complex. */
--	PROCEDURE create_ptt_csv (
--         --
--         -- creates private temporary table "ora$ptt_csv" with columns named in first row of data (case preserved).
--         -- from a CLOB containing CSV lines.
--         -- All fields are varchar2(4000)
--         --
--	     p_clob         CLOB
--	    ,p_separator    VARCHAR2    DEFAULT ','
--	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
--	) IS
--        v_cols          perlish_util_udt; -- for manipulating column names into SQL statement
--        v_sql           CLOB;
--        v_first_row     VARCHAR2(32767);
--        v_ins_curs      INT;
--        v_num_rows      INT;
--        v_last_row_cnt  BINARY_INTEGER := 0;
--        v_col_cnt       BINARY_INTEGER;
--        v_vals_1_row    &&d_arr_varchar2_udt.;  -- from split_csv on 1 line
--        v_rows          DBMS_SQL.varchar2a;     -- from split_clob_to_lines fetch
--        --
--        -- variable number of columns, each of which has a bind array.
--        --
--        TYPE varchar2a_tab  IS TABLE OF DBMS_SQL.varchar2a INDEX BY BINARY_INTEGER;
--        v_vals          varchar2a_tab;          -- array of columns each of which holds array of values
--        --
--        -- We get all but the header row when we read the clob in a loop.
--        --
--        CURSOR c_read_rows IS
--            SELECT t.s
--            FROM TABLE(app_csv_pkg.split_clob_to_lines(p_clob, p_skip_lines => 1))  t
--            ;
--    BEGIN
--        BEGIN
--            -- read the first row only
--            SELECT s INTO v_first_row 
--            FROM TABLE( app_csv_pkg.split_clob_to_lines(p_clob, p_max_lines => 1) )
--            ;
--            IF v_first_row IS NULL THEN
--                raise_application_error(-20222,'app_csv_pkg.create_ptt_csv did not find csv rows in input clob.');
--            END IF;
--        EXCEPTION WHEN NO_DATA_FOUND THEN
--            raise_application_error(-20222,'app_csv_pkg.create_ptt_csv did not find csv rows in input clob.');
--        END;
--        -- split the column header values into collection
--        v_cols := perlish_util_udt(split_csv(v_first_row, p_separator => p_separator, p_strip_dquote => 'Y'));
--        v_col_cnt := v_cols.arr.COUNT;
--
--        -- create the private global temporary table with "known" name and columns matching names found
--        -- in csv first record
--        --
--        v_sql := 'DROP TABLE ora$ptt_csv';
--        BEGIN
--            EXECUTE IMMEDIATE v_sql;
--        EXCEPTION WHEN OTHERS THEN NULL;
--        END;
--
--        v_sql := 'CREATE PRIVATE TEMPORARY TABLE ora$ptt_csv(
--'
--            ||v_cols.map('"$_"    VARCHAR2(4000)').join('
--,')
--            ||'
--)'
--            ;
--        DBMS_OUTPUT.put_line(v_sql);
--        EXECUTE IMMEDIATE v_sql;
--        
--        -- 
--        -- Dynamic sql for dbms_sql. will be used with bind arrays.
--        -- Of note is that it reports conventional load even if specify append.
--        -- I don't understand that as I've seen other reports that direct path load works.
--        -- Does not seem to matter though.
--        --
--        v_sql := 'INSERT INTO ora$ptt_csv(
--'
--        ||v_cols.map('"$_"').join(', ')
--        ||'
--) VALUES (
--'
--        ||v_cols.map(':$##index_val##').join(', ') -- :1, :2, :3, etc...
--        ||'
--)';
--        DBMS_OUTPUT.put_line(v_sql);
--        v_ins_curs := DBMS_SQL.open_cursor;
--        DBMS_SQL.parse(v_ins_curs, v_sql, DBMS_SQL.native);
--
--        OPEN c_read_rows;
--        LOOP
--            FETCH c_read_rows BULK COLLECT INTO v_rows LIMIT 100;
--            EXIT WHEN v_rows.COUNT = 0;
--            FOR i IN 1..v_rows.COUNT
--            LOOP
--                v_vals_1_row := app_csv_pkg.split_csv(v_rows(i), p_separator => p_separator, p_strip_dquote => p_strip_dquote, p_keep_nulls => 'Y');
--                -- j is column number
--                FOR j IN 1..v_col_cnt
--                LOOP
--                    v_vals(j)(i) := v_vals_1_row(j);
--                END LOOP;
--            END LOOP;
--
--            IF v_last_row_cnt != v_rows.COUNT THEN -- will be true on first loop iteration
--                v_last_row_cnt := v_rows.COUNT;
--                -- bind each column array. v_vals has an array for every column
--                FOR j IN 1..v_col_cnt
--                LOOP
--                    DBMS_SQL.bind_array(v_ins_curs, ':'||TO_CHAR(j), v_vals(j), 1, v_last_row_cnt);
--                END LOOP;
--            END IF;
--
--            v_num_rows := DBMS_SQL.execute(v_ins_curs);
--
--        END LOOP;
--        DBMS_SQL.close_cursor(v_ins_curs);
--        CLOSE c_read_rows;
--    END create_ptt_csv
--    ;

    PROCEDURE create_ptt_csv (
         --
         -- creates private temporary table "ora$ptt_csv" with columns named in first row of data case preserved.
         -- All fields are varchar2(4000)
         --
	     p_clob         CLOB
	    ,p_separator    VARCHAR2    DEFAULT ','
	    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
	) IS
        v_cols      perlish_util_udt;
        v_sql       CLOB;
        v_first_row VARCHAR2(32767);
    BEGIN
        BEGIN
            SELECT s INTO v_first_row 
            FROM TABLE( app_csv_pkg.split_clob_to_lines(p_clob, p_max_lines => 1) )
            ;
            IF v_first_row IS NULL THEN
                raise_application_error(-20222,'app_csv_pkg.create_ptt_csv did not find csv rows in input clob.');
            END IF;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            raise_application_error(-20222,'app_csv_pkg.create_ptt_csv did not find csv rows in input clob.');
        END;
        -- split the column header values into collection
        v_cols := perlish_util_udt(split_csv(v_first_row, p_separator => p_separator, p_strip_dquote => 'Y'));

        --
        -- create the private global temporary table with "known" name and columns matching names found
        -- in csv first record
        --
        v_sql := 'DROP TABLE ora$ptt_csv';
        BEGIN
            EXECUTE IMMEDIATE v_sql;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;

        v_sql := 'CREATE PRIVATE TEMPORARY TABLE ora$ptt_csv(
'
            ||v_cols.map('"$_"    VARCHAR2(4000)').join('
,')
            ||'
)'
            ;
        DBMS_OUTPUT.put_line(v_sql);
        EXECUTE IMMEDIATE v_sql;

        -- 
        -- Populate the private global temporary table from all but the first line in the clob.
        -- Binding the clob should be relatively efficient in just passing a pointer.
        -- Even though it has an APPEND hint, the database reports it as a conventional load. 
        -- I'm not sure what's up with that, but nothing I can do about it.
        --
        v_sql := q'[INSERT /*+ APPEND WITH_PLSQL */ INTO ora$ptt_csv 
WITH
a AS (
    SELECT perlish_util_udt(t.arr) AS pu
    FROM TABLE(
                app_csv_pkg.split_lines_to_fields(
                    CURSOR(SELECT * 
                           FROM TABLE( app_csv_pkg.split_clob_to_lines(:p_clob, p_skip_lines => 1) )
                    )
                    , p_separator => :p_separator, p_strip_dquote => :p_strip_dquote, p_keep_nulls => 'Y'
                )
    ) t
) SELECT ]'
        -- must use table alias and fully qualify object name with it to be able to call function or get attribute of object
        -- Thus alias x for a and use x.p.get vs a.p.get.
        ||v_cols.map('X.pu.get($##index_val##) AS "$_"').join('
,')
        ||'
FROM a X';
        DBMS_OUTPUT.put_line(v_sql);
        EXECUTE IMMEDIATE v_sql USING  p_clob, p_separator, p_strip_dquote;

    END create_ptt_csv
    ;


    -- depends on same date/number defaults on deploy system as on one that creates this
    -- you might wind up messing with the column lists and doing explicit conversions
    FUNCTION gen_deploy_insert(
        p_table_name    VARCHAR2
        ,p_where_clause CLOB DEFAULT NULL
        ,p_schema_name  VARCHAR2 DEFAULT NULL -- defaults to current_schema
    ) RETURN CLOB
    IS
        v_sql   CLOB;
    BEGIN
        v_sql := 'SELECT * FROM '||CASE WHEN p_schema_name IS NOT NULL THEN p_schema_name||'.' END||p_table_name;
        IF p_where_clause IS NOT NULL THEN
            v_sql := v_sql||' WHERE '||p_where_clause;
        END IF;
        RETURN 'BEGIN
    APP_CSV_PKG.create_ptt_csv('||APP_LOB.clobtoliterals(p_clob => get_clob(p_sql => v_sql), p_split_on_lf => 'Y')||'
);
END;
'||'/
INSERT INTO '||p_table_name||'
SELECT *
FROM ora$ptt_csv;
COMMIT;'
        ;
    END gen_deploy_insert
    ;

    -- depends on same date/number defaults on deploy system as on one that creates this
    -- you might wind up messing with the column lists and doing explicit conversions
    FUNCTION gen_deploy_merge(
        p_table_name    VARCHAR2
        ,p_key_cols     VARCHAR2 -- CSV list
        ,p_where_clause CLOB DEFAULT NULL
        ,p_schema_name  VARCHAR2 DEFAULT NULL -- defaults to current_schema
    ) RETURN CLOB
    IS
        v_sql       CLOB;
        v_p_on      perlish_util_udt := perlish_util_udt(p_key_cols);--.map('"$_"');
        v_p_upd     perlish_util_udt;
        v_arr_v     &&d_arr_varchar2_udt.;
    BEGIN
        v_sql := q'{SELECT column_name FROM all_tab_columns 
            WHERE owner = '}'||NVL(p_schema_name, SYS_CONTEXT('USERENV','CURRENT_SCHEMA'))
            ||q'{' AND table_name = '}'||p_table_name
            ||q'{' AND column_name NOT IN (}'
            ||v_p_on.map(q'{'$_'}').join(', ')
            ||')
        ORDER BY column_id';
        EXECUTE IMMEDIATE v_sql BULK COLLECT INTO v_arr_v;
        v_p_upd := perlish_util_udt(v_arr_v).map('"$_"');
        v_p_on := v_p_on.map('"$_"');

        v_sql := 'SELECT * FROM '||CASE WHEN p_schema_name IS NOT NULL THEN p_schema_name||'.' END||p_table_name;
        IF p_where_clause IS NOT NULL THEN
            v_sql := v_sql||' WHERE '||p_where_clause;
        END IF;
        RETURN 'BEGIN
    APP_CSV_PKG.create_ptt_csv('||APP_LOB.clobtoliterals(p_clob => get_clob(p_sql => v_sql), p_split_on_lf => 'Y')||'
);
END;
'||'/
MERGE INTO '||p_table_name||' t
USING (
    SELECT *
    FROM ora$ptt_csv
) q
ON (
    '||v_p_on.map('t.$_ = q.$_').join(' AND ')
||'
)
WHEN MATCHED THEN UPDATE SET 
    '||v_p_upd.map('t.$_ = q.$_').join('
    ,')
||'
WHEN NOT MATCHED THEN INSERT(
    '||v_p_on.join(', ')||', '||v_p_upd.join(', ')
||'
) VALUES (
    '||v_p_on.map('q.$_').join(', ')||', '||v_p_upd.map('q.$_').join(', ')
||'
);
COMMIT;'
        ;
    END gen_deploy_merge
    ;
-- end preprocessor directive check for database version
$end

END app_csv_pkg;
/
show errors
