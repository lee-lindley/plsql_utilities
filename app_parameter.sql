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
whenever sqlerror continue
DROP TABLE app_parameters;
prompt ok drop fails for table not exists
whenever sqlerror exit failure
CREATE TABLE app_parameters (
     param_name             VARCHAR2(64)    NOT NULL -- is a PK
    ,param_value            VARCHAR2(4000)
    ,created_by             VARCHAR2(30)    NOT NULL
    ,created_dt             DATE            NOT NULL
    ,end_dated_by           VARCHAR2(30)
    -- live rows have NULL end_date
    ,end_date               DATE 
)
--overkill to use partitions and maybe we do not own a licence
--STORAGE(INITIAL 64K NEXT 64K) -- this is a tiny table. Do not let it pick 8MB which is default for partitions
--PARTITION BY RANGE (end_date) (
--    -- this partition has all the end dated rows
--    PARTITION p_end_dated VALUES LESS THAN (TO_DATE('12/31/2500','MM/DD/YYYY'))
--    -- while the ones that are not end_dated go in the live partition
--    ,PARTITION p_live VALUES LESS THAN (MAXVALUE) -- nulls go here
--)
-- when we replace a row it can move to the end_dated partition
--ENABLE ROW MOVEMENT
;
--ALTER TABLE app_parameters ADD CONSTRAINT app_parameters_pk UNIQUE(param_name, end_date) USING INDEX LOCAL;
ALTER TABLE app_parameters ADD CONSTRAINT app_parameters_pk UNIQUE(param_name, end_date);
COMMENT ON TABLE app_parameters IS 'Use the function get_app_parameters to retrieve values
 - it uses function caching for efficiency.
 If you query the table, qualify the query with WHERE end_date IS NULL.
 For DML it is strongly encouraged to use package app_parameter; -
 otherwise, you are on your own with a good chance that integrity constraints
 and triggers will thwart and vex you!!!';
COMMENT ON COLUMN app_parameters.param_name IS 'Case sensitive name for a app_parameters/value pair used for looking up the value';
COMMENT ON COLUMN app_parameters.param_value IS 'Case sensitive value for a app_parameters/value pair returned by function get_app_parameters';
COMMENT ON COLUMN app_parameters.created_by IS 'Automatically populated with the Session User Name when record is created';
COMMENT ON COLUMN app_parameters.created_dt IS 'Automatically populated with the SYSDATE Date/Time value when record is created';
COMMENT ON COLUMN app_parameters.end_dated_by IS 'Automatically populated with the Session User Name who caused the record to be end_dated';
COMMENT ON COLUMN app_parameters.end_date IS 'Automatically populated with the SYSDATE Date/Time value when the record was end_dated. Live records have NULL for end_date.';
--
--
--GRANT SELECT ON app_parameters TO ???;
--
-- It would be best if anyone trying to add/update/delete values from the table used the package
-- procedures in app_parameter, but if one insists on doing direct DML, we have some triggers
-- to try to keep you out of trouble.
-- 
CREATE OR REPLACE TRIGGER app_parameters_ins
    BEFORE INSERT ON app_parameters
    FOR EACH ROW
        WHEN (NEW.created_by IS NULL OR NEW.created_dt IS NULL)
        BEGIN
            :NEW.created_by := SYS_CONTEXT('USERENV','SESSION_USER');
            :NEW.created_dt := SYSDATE;
        END;
/
show errors
CREATE OR REPLACE TRIGGER app_parameters_upd
    BEFORE UPDATE OR DELETE ON app_parameters
    FOR EACH ROW
        WHEN (NEW.end_date IS NULL OR NEW.end_dated_by IS NULL)
        BEGIN
            IF :NEW.end_date IS NULL THEN
                RAISE_APPLICATION_ERROR(-20001, 'Must end_date a record to update app_parameters table. Should not be deleting. Use app_parameter procedures instead. param_name='||:NEW.param_name);
            END IF;
            IF :NEW.end_dated_by IS NULL THEN
                :NEW.end_dated_by := SYS_CONTEXT('USERENV','SESSION_USER');
            END IF;
        END;
/
show errors
--
-- the function for retrieving parameter values has a different set of users than
-- the facility for modifying it.
--
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
END get_app_parameter;
/
show errors
--GRANT EXECUTE ON get_app_parameter TO ???;
--
CREATE OR REPLACE PACKAGE app_parameter AS
    --
    -- Provides smart DML procedures 
    -- on table app_parameters. Parameter Facility users are encouraged to use this package
    -- for doing any DML.
    --
    PROCEDURE end_app_parameter(p_param_name VARCHAR2); -- probably very seldom used to get rid of one
    PROCEDURE create_or_replace(p_param_name VARCHAR2, p_param_value VARCHAR2);
    -- these are specialized for a scenario where production data is cloned to a test system 
    -- and you do not want the parameters from production used to do bad things in the test system
    -- Obscure and probably not useful to you.
    FUNCTION is_matching_database RETURN BOOLEAN;
    FUNCTION get_database_match RETURN VARCHAR2;
    PROCEDURE set_database_match; -- do this after updating the other app_parameters following a db refresh from prod
END app_parameter;
/
show errors
CREATE OR REPLACE PACKAGE BODY app_parameter AS

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
--
--GRANT EXECUTE ON app_parameter TO ???;
--
-- we create our first parameter.
EXECUTE app_parameter.set_database_match;
