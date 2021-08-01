CREATE OR REPLACE FUNCTION get_app_parameter(
    p_param_name VARCHAR2
) RETURN VARCHAR2 
RESULT_CACHE
IS
    v_ret VARCHAR2(4000);
BEGIN
    BEGIN
        SELECT param_value INTO v_ret 
        FROM app_parameters
        WHERE end_date IS NULL 
            AND param_name = p_param_name;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        v_ret := NULL;
    END;
    RETURN v_ret;
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
END get_app_parameter;
/
show errors
--
-- the function for retrieving parameter values has a different set of users than
-- the facility for modifying it.
--
--GRANT EXECUTE ON get_app_parameter TO ???;
