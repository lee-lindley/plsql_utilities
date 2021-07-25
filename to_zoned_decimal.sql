whenever sqlerror exit failure
--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
CREATE OR REPLACE FUNCTION to_zoned_decimal(
    p_number                NUMBER
    ,p_length               BINARY_INTEGER          -- S9(7)V99 then 7
    ,p_digits_after_decimal BINARY_INTEGER := NULL  -- S9(7)V99 then 2
) RETURN VARCHAR2
DETERMINISTIC
-- turns the input number into a mainframe S999 or S999V99 type field
-- where the rightmost digit character is overloaded with the sign.
-- This function assumes that for S9V99 you have multiplied by 100 before calling or else provided
-- optional argument with the number of digits to the right of the decimal.
--
-- to output as S9(7)V99                to_zoned_decimal(54321.987542122211, 7, 2)
-- OR you for same result you can do    to_zoned_decimal(54321.987542122211 * 100.0, 9)
--
-- converting a file that contains zoned decimal can be done with sqlldr and probably external tables,
-- but I do not see anything to write out values as zoned decimal. Trivial to do and everyone
-- builds their own I suspect.
--
AS 
    -- we will raise an exception if the length paramter is invalid
    invalid_length_arg  EXCEPTION;
    invalid_decimal_arg EXCEPTION;
    value_too_large     EXCEPTION;
    PRAGMA exception_init(invalid_length_arg, -20887);
    PRAGMA exception_init(invalid_decimal_arg, -20888);
    PRAGMA exception_init(value_too_large, -20889);
--
    v_number        NUMBER(32);
    is_negative     BOOLEAN := FALSE;
    v_out           VARCHAR2(100);
    v_last_digit    BINARY_INTEGER;
    v_length        BINARY_INTEGER := p_length + NVL(p_digits_after_decimal,0);
BEGIN
    IF p_length IS NULL -- provide 0 if you have everything after the decimal
        OR v_length NOT BETWEEN 1 AND  32 
    THEN --??? not sure max mainframe zoned decimal digts
        raise_application_error(-20887,'p_length parameter was not between 1 and 32');
    END IF;
    -- put the potentially decimal number into 
    IF p_digits_after_decimal NOT BETWEEN 0 AND 31 -- null is fine
    THEN
        raise_application_error(-20888,'p_digits_after_decimal parameter was not between 0 and 32');
    ELSIF NVL(p_digits_after_decimal,0) <> 0 THEN
        v_number := NVL(ROUND(p_number * (10 ** p_digits_after_decimal), 0), 0);
    ELSE
        v_number := NVL(ROUND(p_number, 0),0); -- in case passed decimal val rather than whole number
    END IF;
    --
    IF v_number < 0 THEN
        is_negative := TRUE;
        v_number := v_number * -1;
    END IF;
    v_last_digit := MOD(v_number,10); -- remainder after divide (mod) by 10 is the right most digit
    -- dont want a pesky sign in the string. Also trim off the leading space if any
    v_out := LTRIM(TO_CHAR(v_number, '999999999999999999999999999999999'));
    IF LENGTH(v_out) > v_length THEN
            raise_application_error(-20889,'number exceeds p_length+p_digits_after_decimal digits');
    END IF;
    v_out := SUBSTR(v_out,1,LENGTH(v_out)-1) -- get all but the right most digit
        -- now put in a zoned decimal char for the right most digit. Use substr and the value of the last
        -- digit as trickery to pull it out rather than a nasty big case.
        ||SUBSTR(CASE WHEN is_negative
                        THEN '}JKLMNOPQR'
                        ELSE '{ABCDEFGHI'
                 END
                 ,v_last_digit+1 -- 0-9 needs to be 1-10
                 ,1
                )
    ;
    RETURN LPAD(v_out,v_length,'0');
END to_zoned_decimal
;
/
show errors
GRANT EXECUTE ON to_zoned_decimal TO PUBLIC;
--ALTER SESSION SET plsql_optimize_level=2; 
--ALTER SESSION SET plsql_code_type = INTERPRETED;
