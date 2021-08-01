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
--
-- since the value can be NULL we cannot use PRIMARY KEY directly, but this serves the same purpose.
ALTER TABLE app_parameters ADD CONSTRAINT app_parameters_pk UNIQUE(param_name, end_date);
--
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
