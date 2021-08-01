CREATE OR REPLACE PACKAGE app_parameter AS
    --
    -- Provides smart DML procedures 
    -- on table app_parameters. Parameter Facility users are encouraged to use this package
    -- for doing any DML.
    --
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
