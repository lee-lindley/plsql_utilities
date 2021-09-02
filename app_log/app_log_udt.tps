CREATE OR REPLACE TYPE app_log_udt FORCE AS OBJECT (
/* 
    Purpose: Provide general purpose logging capability for PL/SQL applications


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



    Tables: app_log_app     -- small automatically populated lookup table app_name/app_id pairs
            app_log         -- all log records by app_id (actually a synonym to one of 2 base tables)
    Views: app_log_base_v   -- uses the synonym to pick the base table
           app_log_v        -- joins on app_id to provide a view that includes the app_name string
           app_log_tail_v   -- last 20 records of log joined on app_id with elapsed time from prior record

    Type: app_log_udt       -- an object type with constructor and methods for performing simple logging

    Example of using this object:

        DECLARE
            -- instantiate an object instance for app_name 'bnft' which will automatically
            -- create the app_log_app entry if it does not exist
            v_log_obj   app_log_udt := app_log_udt('bnft');
        BEGIN
            -- log a message for our app
            v_log_obj.log('whatever my message: '||sqlerrm);
            -- same but also do DBMS_OUTPUT.PUT_LINE with the message too
            v_log_obj.log_p('whatever my message: '||sqlerrm);
        END;

    Example of an exception block:

        Assumes the following declarations in the program:
            g_sqlerrm                       VARCHAR2(512);
            g_backtrace                     VARCHAR2(32767);
            g_callstack                     VARCHAR2(32767); 
            g_log       app_log_udt := app_log_udt('my application name string');
        ...
        EXCEPTION WHEN OTHERS THEN
            g_sqlerrm := SQLERRM;
            g_backtrace := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            g_callstack := DBMS_UTILITY.FORMAT_CALL_STACK;
            g_log.log_p('sqlerrm    : '||g_sqlerrm);
            g_log.log_p('backtrace  : '||g_backtrace);
            g_log.log_p('callstack  : '||g_callstack);
            RAISE;

    Example of calling the static logging of a message without declaring/initializing 
    an instance of the object. Not efficient, but ok for exception blocks
        app_log_udt.log('my app string', 'some message');
        app_log_udt.log_p('my app string', 'some message');

*/
    app_id      NUMBER(38)
    ,app_name   VARCHAR2(30)
    -- member functions and procedures
    ,CONSTRUCTOR FUNCTION app_log_udt(p_app_name VARCHAR2)
        RETURN SELF AS RESULT
    ,FINAL MEMBER PROCEDURE app_log_udt_constructor(
        SELF IN OUT app_log_udt
        ,p_app_name VARCHAR2
    )
    ,FINAL MEMBER PROCEDURE log(p_msg VARCHAR2)
    ,FINAL MEMBER PROCEDURE log_p(p_msg VARCHAR2) -- prints with dbms_output and then logs
    -- these are not efficient, but not so bad in an exception block.
    -- You do not have to declare a variable to hold the instance because it is temporary
    ,FINAL STATIC PROCEDURE log(p_app_name VARCHAR2, p_msg VARCHAR2) 
    ,FINAL STATIC PROCEDURE log_p(p_app_name VARCHAR2, p_msg VARCHAR2) 
    -- should only be used by the schema owner, but only trusted application accounts
    -- are getting execute on this udt, so fine with me. If you are concerned, then
    -- break this procedure out standalone
    ,FINAL STATIC PROCEDURE purge_old(p_days NUMBER := 90)
)
NOT FINAL
;
/
show errors
