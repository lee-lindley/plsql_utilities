whenever sqlerror exit failure
CREATE OR REPLACE FUNCTION transform_perl_regexp(p_re VARCHAR2)
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
END transform_perl_regexp;
/
show errors
GRANT EXECUTE ON transform_perl_regexp TO PUBLIC;

