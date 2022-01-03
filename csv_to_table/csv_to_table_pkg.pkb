CREATE OR REPLACE PACKAGE BODY csv_to_table_pkg AS
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


    -- private functions defined at the end of the package
    FUNCTION transform_perl_regexp(p_re VARCHAR2)
    RETURN VARCHAR2 DETERMINISTIC
    ;
    FUNCTION split (
        p_s            VARCHAR2
        ,p_separator    VARCHAR2    DEFAULT ','
        ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
        ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
    ) RETURN &&char_collection_type. DETERMINISTIC
    ;


    --
    -- split a clob into a row for each line.
    -- Handle case where a "line" can have embedded LF chars per RFC for CSV format
    -- Throw out completely blank lines (but keep track of line number)
    --
    FUNCTION split_clob_to_lines(p_clob CLOB)
    RETURN t_arr_csv_row_rec
    PIPELINED
    IS
        v_cnt           BINARY_INTEGER;
        v_row           t_csv_row_rec;

        v_rows_regexp   VARCHAR2(1024) := transform_perl_regexp('
(                               # capture in \1
  (                             # going to group 0 or more of these things
    [^"\n\\]+                   # any number of chars that are not dquote, backwack or newline
    |
    (                           # just grouping for repeat
        \\ \n                   # or a backwacked \n but put space between them so gets transformed correctly
    )+                          # one or more protected newlines (as if they were in dquoted string)
    |
    (                           # just grouping for repeat
        \\"                     # or a backwacked "
    )+                          # one or more protected "
    |
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
    \\                          # or a backwack, but do this last as it is the smallest and we do not want
                                #   to consume the backwack before a newline or a dquote
  )*                            # zero or more strings on a single "line" that could include newline in dquotes
                                # or even a backwacked newline
)                               # end capture \1
(                               # just grouping 
    $|\n                        # require match newline or string end 
)                               # close grouping
'       );
    BEGIN
        v_cnt := REGEXP_COUNT(p_clob, v_rows_regexp) - 1; -- we get an extra match on final $
        FOR i IN 1..v_cnt
        LOOP
            v_row.s := REGEXP_SUBSTR(p_clob, v_rows_regexp, 1, i, NULL, 1);
            IF v_row.s IS NOT NULL THEN
                v_row.rn := i;
                PIPE ROW(v_row);
            END IF;
        END LOOP;
        RETURN;
    END split_clob_to_lines
    ;

    /*
        Expect input data to be rows of CSV lines (VARCHAR2 strings), plus 
        an optional row number column for reporting. The optional column allows us to report
        the rownumber in the original data before it was split into rows and handed to us.
        The reason is that rows may be removed before we get them but we want to report
        on the original line number.

        If the optional rownumber is not included, we will use a running count.

        Each CSV row string will be split into fields which will then populate the output columns
        that will match p_table_name/p_columns names and types. Conversion from string to type
        is part of the magic of this PTF.
    */
    FUNCTION describe(
        p_tab IN OUT    DBMS_TF.TABLE_T
        ,p_columns      VARCHAR2 -- csv list
        ,p_table_name   VARCHAR2
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN DBMS_TF.DESCRIBE_T
    AS
        v_new_cols  DBMS_TF.columns_new_t;
        v_col_names &&char_collection_type.;

        -- a hash with key of column name and value of the column position in the CSV and output columns
        TYPE t_col_order IS TABLE OF BINARY_INTEGER INDEX BY VARCHAR2(128);
        v_col_order t_col_order;
        
    BEGIN
        IF p_tab.column(1).description.type != DBMS_TF.type_varchar2
        THEN
            RAISE_APPLICATION_ERROR(-20100,'Input table to csv_to_table_pkg.ptf must have a CSV string column first that is VARCHAR2. First column was not VARCHAR2 type');
        END IF;
        IF p_tab.column.COUNT > 2 THEN
            RAISE_APPLICATION_ERROR(-20101,'Input table to csv_to_table_pkg.ptf must have a CSV string column first and optional rownumber. We have '||p_tab.column.COUNT()||' columns in the input, not 1 or 2.');
        END IF;

        p_tab.column(1).pass_through := FALSE;
        p_tab.column(1).for_read := TRUE;

        IF p_tab.column.COUNT() = 2 THEN
            p_tab.column(2).pass_through := FALSE;
            p_tab.column(2).for_read := TRUE;
            IF p_tab.column(2).description.type != DBMS_TF.type_number THEN
                RAISE_APPLICATION_ERROR(-20102,'Input table to csv_to_table_pkg.t must have a CSV string column first and optional line number second. Our second column is not a number');
            END IF;
        END IF;

        v_col_names := split(p_columns, p_separator => p_separator, p_strip_dquote => 'N');
        -- we need a hash to get from the column name to the index for both input csv order and output field order
        -- We could depend on the order Oracle delivers it from the TABLE(v_col_names) construct and casual
        -- testing says it would work, but it is not defined to do so and could break in a future release. Unlikely, but...
        FOR i IN 1..v_col_names.COUNT
        LOOP
            IF SUBSTR(v_col_names(i),1,1) = '"' THEN
                v_col_names(i) := REPLACE(v_col_names(i), '"'); -- strip dquotes and keep case
            ELSE
                v_col_names(i) := UPPER(v_col_names(i));
            END IF;
            v_col_order(v_col_names(i)) := i;
        END LOOP;

        --
        -- Determine the datatypes of the output fields and set up to deliver them in v_new_cols
        --
        FOR r IN (
            SELECT c.column_value AS column_name
                -- we could have a table in our schema and another with same name in a different
                -- schema that we have access to. This gives preference to the one in current schema
                ,MAX(CASE WHEN a.data_type LIKE 'TIMESTAMP%' THEN 'TIMESTAMP' ELSE a.data_type END)
                    KEEP (DENSE_RANK FIRST ORDER BY CASE WHEN owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA') THEN 1 ELSE 2 END)
                AS data_type
            FROM TABLE(v_col_names) c
            LEFT OUTER JOIN all_tab_columns a
                ON a.table_name = UPPER(p_table_name)
                    AND a.column_name = c.column_value
            GROUP BY c.column_value
        ) LOOP
            IF r.data_type IS NULL THEN
                RAISE_APPLICATION_ERROR(-20103,'table: '||p_table_name||' does not have a column named '||r.column_name);
            ELSIF r.data_type = 'BLOB' OR r.data_type LIKE 'INTERVAL%' THEN
                RAISE_APPLICATION_ERROR(-20104,'table: '||p_table_name||' column '||r.column_name||' is unsupported data type '||r.data_type);
            END IF;
            -- we create these in the order they came out of the query, but they must be in the right location in the array
            v_new_cols(v_col_order(r.column_name)) := DBMS_TF.column_metadata_t(
                                        name    => '"'||r.column_name||'"' -- protect case
                                        ,type   => CASE r.data_type
                                                    WHEN 'TIMESTAMP'        THEN DBMS_TF.type_timestamp
                                                    WHEN 'BINARY_DOUBLE'    THEN DBMS_TF.type_binary_double
                                                    WHEN 'BINARY_FLOAT'     THEN DBMS_TF.type_binary_float
                                                    --WHEN 'BLOB'             THEN DBMS_TF.type_blob
                                                    WHEN 'CHAR'             THEN DBMS_TF.type_char
                                                    WHEN 'CLOB'             THEN DBMS_TF.type_clob
                                                    WHEN 'DATE'             THEN DBMS_TF.type_date
                                                    WHEN 'NUMBER'           THEN DBMS_TF.type_number
                                                    ELSE                         DBMS_TF.type_varchar2
                                                   END
                                    );
        END LOOP;

        RETURN DBMS_TF.describe_t(new_columns => v_new_cols);
    END describe
    ;

    PROCEDURE fetch_rows(
         p_columns      VARCHAR2 -- csv list. not used here
        ,p_table_name   VARCHAR2
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
        ,p_separator    VARCHAR2 DEFAULT ','
    ) AS
        v_env               DBMS_TF.env_t ;
        v_has_rn            BOOLEAN ;           -- whether our input rows have a line number column
        --
        v_rowset            DBMS_TF.row_set_t;  -- the input rowset of CSV rows
        v_in_row_cnt        BINARY_INTEGER;
        --
        v_rowset_out        DBMS_TF.row_set_t;  -- the output rowset of typed data columns
        v_col_out_cnt       BINARY_INTEGER;     -- number of columns in our output
        v_output_col_type   BINARY_INTEGER;     -- a local holder of the column type
        --
        v_col_strings       &&char_collection_type.;   -- array of strings from splitting the CSV row into fields

        g_row_num           NUMBER := 0;        -- the overall row number for the query of the original input lines
    BEGIN
        v_env := DBMS_TF.get_env(); 
        -- the number of columns in our output rows should match number of csv fields
        v_col_out_cnt := v_env.put_columns.COUNT();

        -- whether or not our input has a Row Number column
        v_has_rn := v_env.get_columns.COUNT = 2;

        IF NOT v_has_rn THEN
            -- Since we do not have a line number column in our input, we have to track it ourselves
            -- This is in case FETCH is called more than once. We get and put to the store
            -- what the last FETCH count total was and keep adding to it.
            -- get does not change value if not found in store so starts with our default 0 on first fetch call
            DBMS_TF.xstore_get('g_row_num', g_row_num); 
        END IF;

        DBMS_TF.get_row_set(v_rowset, row_count => v_in_row_cnt);
        -- for this set of input rows on a call to fetch, iterate over the rows
        FOR i IN 1..v_in_row_cnt
        LOOP
            IF v_has_rn THEN
                -- column 2 value for this row is the input data line number
                g_row_num := v_rowset(2).tab_number(i);
            ELSE
                g_row_num := g_row_num + 1;
            END IF;

            -- split the CSV row into column value strings taking care of any unquoting needed according to RFC for CSV
            -- column 1, row i in the input resultset
            v_col_strings := split(v_rowset(1).tab_varchar2(i), p_separator => p_separator, p_keep_nulls   => 'Y');

            IF v_col_strings.COUNT != v_col_out_cnt THEN
                RAISE_APPLICATION_ERROR(-20201,'row '||g_row_num||' has cnt='||v_col_strings.COUNT||' csv fields, but we need '||v_col_out_cnt||' columns
ROW: '||v_rowset(1).tab_varchar2(i) 
);
            END IF;
            -- populate the output rowset column tables for this row
            FOR j IN 1..v_col_out_cnt   -- for each column
              LOOP
                v_output_col_type := v_env.put_columns(j).TYPE;
                -- for most of them we depend on the default conversion from string to Oracle data type
                BEGIN -- let us trap conversion errors and report the problem row
                    IF v_output_col_type = DBMS_TF.type_timestamp THEN
                        -- better set nls value yourself because we just shoving the string in with default conversion
                        -- likely not to ever be used
                        v_rowset_out(j).tab_timestamp(i)        := v_col_strings(j);
                    ELSIF v_output_col_type = DBMS_TF.type_binary_double THEN
                        v_rowset_out(j).tab_binary_double(i)    := v_col_strings(j);
				    ELSIF v_output_col_type = DBMS_TF.type_binary_float THEN
                        v_rowset_out(j).tab_binary_float(i)     := v_col_strings(j);
				    ELSIF v_output_col_type = DBMS_TF.type_char THEN
                        v_rowset_out(j).tab_char(i)             := v_col_strings(j);
				    ELSIF v_output_col_type = DBMS_TF.type_clob THEN
                        v_rowset_out(j).tab_clob(i)             := v_col_strings(j);
				    ELSIF v_output_col_type = DBMS_TF.type_date THEN
                        IF p_date_fmt IS NULL THEN
                            v_rowset_out(j).tab_date(i)         := v_col_strings(j); -- default to nls_date_fmt
                        ELSE
                            v_rowset_out(j).tab_date(i)         := TO_DATE(v_col_strings(j), p_date_fmt);
                        END IF;
				    ELSIF v_output_col_type = DBMS_TF.type_number THEN
                        v_rowset_out(j).tab_number(i)           := v_col_strings(j);
                    ELSE -- in describe we made sure the only thing left is varchar2
                        v_rowset_out(j).tab_varchar2(i)         := v_col_strings(j);
                    END IF;
                EXCEPTION WHEN OTHERS THEN
                    RAISE_APPLICATION_ERROR(-20202,'line number:'||g_row_num||' col:'||i||' 
Line: '||v_rowset(1).tab_varchar2(i)||'
has Oracle error: '||SQLERRM);
                END;
            END LOOP; -- end loop on columns
        END LOOP; -- end loop on newline separated rows in clob

        IF NOT v_has_rn THEN    -- save for possible next fetch call
            DBMS_TF.xstore_set('g_row_num', g_row_num);
        END IF;

        DBMS_TF.put_row_set(v_rowset_out);
    END fetch_rows;

    FUNCTION transform_perl_regexp(p_re VARCHAR2)
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
    END transform_perl_regexp;


  FUNCTION split (
     p_s            VARCHAR2
    ,p_separator    VARCHAR2    DEFAULT ','
    ,p_keep_nulls   VARCHAR2    DEFAULT 'N'
    ,p_strip_dquote VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
  ) RETURN &&char_collection_type. DETERMINISTIC
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
  IS
        v_str       VARCHAR2(32767);    -- individual parsed values cannot exceed 4000 chars
        v_occurence BINARY_INTEGER := 1;
        v_i         BINARY_INTEGER := 0;
        v_cnt       BINARY_INTEGER;
        v_arr       &&char_collection_type. := &&char_collection_type.();

        -- we are going to match multiple times. After each match the position 
        -- will be after the last separator.
        v_regexp    VARCHAR2(128) := transform_perl_regexp('
\s*                         -- optional whitespace before anything, or after
                            -- last delim
                            --
   (                        -- begin capture of \1 which is what we will return.
                            -- It can be NULL!
                            --
       "                        -- one double quote char binding start of the match
           (                        -- just grouping
 --
 -- order of these next things matters. Look for longest one first
 --
               ""                       -- literal "" which is a quoted quote 
                                        -- within dquote string
               |                        
               \\"                      -- Then how about a backwacked double
                                        -- quote???
               | 
               [^"]                     -- char that is not a closing quote
           )*                       -- 0 or more of those chars greedy for
                                    -- field between quotes
                                    --
       "                        -- now the closing dquote 
       |                        -- if not a double quoted string, try plain one
 --
 -- if the capture is not going to be null or a "*" string, then must start 
 -- with a char that is not a separator or a "
 --
       [^"'||p_separator||']    -- so one non-sep, non-" character to bind 
                                -- start of match
                                --
           (                        -- just grouping
 --
 -- order of these things matters. Look for longest one first
 --
               \\'||p_separator||'      -- look for a backwacked separator
               |                        
               [^'||p_separator||']     -- a char that is not a separator
           )*                       -- 0 or more of these non-sep, non backwack
                                    -- sep chars after one starting (bound) a 
                                    -- char 1 that is neither sep nor "
                                    --
   )?                       -- end capture of our field \1, and we want 0 or 1
                            -- of them because we can have ,,
 --
 -- Since we allowed zero matches in the above, regexp_subst can return null
 -- or just spaces in the referenced grouped string \1
 --
   ('||p_separator||'|$)    -- now we must find a literal separator or be at 
                            -- end of string. This separator is included and 
                            -- consumed at the end of our match, but we do not
                            -- include it in what we return
');
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
  END split
    ;


END csv_to_table_pkg;
/
show errors
