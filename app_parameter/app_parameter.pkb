CREATE OR REPLACE PACKAGE BODY app_parameter AS
--
-- General purpose application parameter table for holding things like email addresses and program settings
-- rather than hard coding them.
--
-- A production GUI front end for it for IT admin would be a good idea. The construct takes
-- care of logging changes by saving the old records and who did it when using the "end_date" concept.
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

    -- private procedure called by public procedures create_or_replace and end_app_parameter
    PROCEDURE create_or_replace(p_param_name VARCHAR2, p_param_value VARCHAR2, p_has_new BOOLEAN)
    IS -- does both end_app_parameter() and create_or_replace()
        v_sess_user         VARCHAR2(30) := SYS_CONTEXT('USERENV','SESSION_USER');
        v_param_value_found VARCHAR2(4000) := NULL;
    BEGIN
        BEGIN -- we may not save this change!
            UPDATE app_parameters
            SET end_dated_by = v_sess_user
                ,end_date = SYSDATE
            WHERE end_date IS NULL AND param_name = p_param_name
            -- we want to know if it is a useless update. end_app_parameter() will pass in NULL so will not trigger 
            RETURNING param_value INTO v_param_value_found
            ; -- might be no rows
        EXCEPTION WHEN no_data_found THEN NULL;
        END;

        -- end_app_parameter passes in NULL for p_param_value so will not be true for that case
        IF v_param_value_found = p_param_value THEN -- no reason to change existing record
            ROLLBACK; -- silently ignore update request that does not change the value
            -- we will create useless records if old and new values are both null. not going to worry about it
        ELSIF p_has_new THEN -- we will commit the end_dating done above if any, as well as the insert
            -- if you pass NULL for p_param_name, will fail on not null constraint on PK 
            -- null param_value is fine
            INSERT INTO app_parameters(param_name, param_value, created_by, created_dt)
                VALUES(p_param_name, p_param_value, v_sess_user, SYSDATE)
            ;
            COMMIT;
        ELSE -- this would be end_app_paramter case so just committing the end_date update above
            COMMIT;
        END IF;
    END create_or_replace;

    PROCEDURE end_app_parameter(p_param_name VARCHAR2)
    IS
    BEGIN
        -- by setting third param p_has_new to false, we do not try to create a record in the "live" partition
        -- after end_date-ing the current row.
        create_or_replace(p_param_name, NULL, FALSE);
    END end_app_parameter;

    PROCEDURE create_or_replace(p_param_name VARCHAR2, p_param_value VARCHAR2 )
    IS
    BEGIN
        -- p_param_value may be a null value but it must have been deliberately provided. There is no default.
        create_or_replace(p_param_name, p_param_value, TRUE);
    END create_or_replace
    ;

    FUNCTION is_matching_database 
    RETURN BOOLEAN
    IS
    BEGIN
        -- CON_NAME should work for pluggable databases too
        RETURN get_app_parameter('Database Name') = SYS_CONTEXT('USERENV','CON_NAME');
    END is_matching_database;

    FUNCTION get_database_match 
    RETURN VARCHAR2
    IS
    BEGIN
        RETURN CASE WHEN is_matching_database
                    THEN 'Y'
                    ELSE 'N'
               END;
    END get_database_match;

    PROCEDURE set_database_match
    IS
    BEGIN
        -- CON_NAME should work for pluggable databases too
        create_or_replace('Database Name', SYS_CONTEXT('USERENV','CON_NAME'));
    END set_database_match;

END app_parameter;
/
show errors
