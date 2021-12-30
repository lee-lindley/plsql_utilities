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
prompt calling app_parameters.sql
@@app_parameters.sql
prompt calling app_parameters.trg
@@app_parameters.trg
prompt calling get_app_parameters.sql
@@get_app_parameters.sql
prompt calling app_parameter.pks
@@app_parameter.pks
prompt calling app_parameter.pkb
@@app_parameter.pkb
--
--GRANT EXECUTE ON app_parameter TO ???;
--
-- we create our first parameter.
EXECUTE app_parameter.set_database_match;
