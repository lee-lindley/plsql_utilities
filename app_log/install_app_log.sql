--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
/*
  Author: Lee Lindley
  Date: 07/24/2021

  Copyright (C) 2021 by Lee Lindley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/
--
-- General purpose logging components.
-- The core is an object oriented user defined type with logging methods.
--
-- Since the autonomous transactions write independently, you can get status
-- of the program before "succesful" completion that might be required for dbms_output.
-- For long running processes that means you can "tail" the log (select * from app_log_tail_v)
-- to watch what is happening. It also means that if the thing blows up or is hung,
-- and does not display the dbms_output for you, you can still go see it in the log table.
--
-- Since the messages include a high precision timestamp, you can see from the time between
-- log messages the elapsed time for operations. Mining the log for this information is fun.
-- The view app_log_tail_v shows you how to use an analytic to calculate that elapsed time.
--
-- In addition to generally useful logging, it is indispensable for debugging and development.
--
whenever sqlerror continue
DROP TYPE app_log_udt FORCE;
prompt ok drop failed for type not exists
DROP VIEW app_log_v;
prompt ok if drop failed for view not exists
DROP VIEW app_log_base_v;
prompt ok if drop failed for view not exists
DROP VIEW app_log_tail_v;
prompt ok if drop failed for view not exists
--
DROP TABLE app_log_1;
DROP TABLE app_log_2;
prompt ok if drop fails for table not exists
DROP TABLE app_log_app;
prompt ok if drop fails for table not exists
DROP SEQUENCE app_log_app_seq;
prompt ok if drop fails for sequence not exists
--
whenever sqlerror exit failure
prompt calling app_log_app.sql
@&&subdir/app_log_app.sql
prompt calling app_log.sql to create tables
@&&subdir/app_log.sql
prompt calling app_log_views.sql
@&&subdir/app_log_views.sql
prompt calling app_log_udt.tps
@&&subdir/app_log_udt.tps
prompt calling app_log_udt.tpb
@&&subdir/app_log_udt.tpb
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
--
-- put a record into the log for funzies
DECLARE
    v_logger app_log_udt := app_log_udt('app_log');
BEGIN
    v_logger.log('This will be the first message in the log after code deploy from app_log.sql');
END;
/
--GRANT EXECUTE ON app_log_udt TO ???; -- trusted application schemas only. Not people
-- select can be granted to roles and people who are trusted to see log messages.
-- that depends on what you are putting in the log messages. Hopefully no secrets.
--GRANT SELECT ON app_log_1 TO ???; 
--GRANT SELECT ON app_log_2 TO ???; 
--GRANT SELECT ON app_log_app TO ???; 
--GRANT SELECT ON app_log_v TO ???; 
--GRANT SELECT ON app_log_tail_v TO ???; 
--GRANT SELECT ON app_log_base_v TO ???;
