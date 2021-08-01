BEGIN -- cause need compile directives
EXECUTE IMMEDIATE q'[
CREATE OR REPLACE TYPE html_email_udt AS OBJECT (
    /*
        An object for creating and sending an email message with an HTML
        body and optional attachments.
        A utility static function can return an HTML table from a query string
        or cursor for general use in addition to adding it to an email body.
    */
-- See note in deployment file if you get ORA-24247 upon execution.
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
--
--
--    Note that you do not put in the <header></header><body></body> tags as the
--    send procedure will do that.
--    The Subject will become the HTML title in the header.
--
--    Here is an example that puts the results of a query both into the body of
--    the email as an HTML table as well as attaching it as an XLSX file. 
--
--    DECLARE
--        v_email         html_email_udt;
--        v_src           SYS_REFCURSOR;
--        v_query         VARCHAR2(32767) := q'!SELECT --+ no_parallel 
--                v.view_name AS "View Name"
--                ,c.comments AS "Comments"
--            FROM dictionary d
--            INNER JOIN all_views v
--                ON v.view_name = d.table_name
--            LEFT OUTER JOIN all_tab_comments c
--                ON c.table_name = v.view_name
--            WHERE d.table_name LIKE 'ALL%'
--            ORDER BY v.view_name
--            FETCH FIRST 40 ROWS ONLY!';
--        --
--        -- Because you cannot CLOSE/ReOPEN a dynamic sys_refcursor variable directly,
--        -- you must regenerate it and assign it. Weird restriction, but do not
--        -- try to fight it by opening it in the main code twice. Get a fresh copy from a function.
--        FUNCTION l_getcurs RETURN SYS_REFCURSOR IS
--            l_src       SYS_REFCURSOR;
--        BEGIN
--            OPEN l_src FOR v_query;
--            RETURN l_src;
--        END;
--    BEGIN
--        v_email := html_email_udt(
--            p_to_list   => 'myname@google.com, yourname@yahoo.com'
--            ,p_from_email_addr  => 'myname@mycompany.com'
--            ,p_reply_to         => 'donotreply@nohost'
--            ,p_smtp_server      => 'smtp.mycompany.com'
--            ,p_subject          => 'A sample email from html_email_udt'
--        );
--        v_email.add_paragraph('We constructed and sent this email with html_email_udt.');
--        v_src := l_getcurs;
--        --v_email.add_to_body(html_email_udt.cursor_to_table(p_refcursor => v_src, p_caption => 'DBA Views'));
--        v_email.add_table_to_body(p_refcursor => v_src, p_caption => 'DBA Views');
--        -- we need to close it because we are going to open again.
--        -- The called package may have closed it, but must be sure or nasty 
--        -- bugs/caching can happen.
--        BEGIN
--            CLOSE v_src;
--        EXCEPTION WHEN invalid_cursor THEN NULL;
--        END;
--
--        -- https://github.com/mbleron/ExcelGen
--        DECLARE
--            l_xlsx_blob     BLOB;
--            l_ctxId         ExcelGen.ctxHandle;
--            l_sheet_handle  BINARY_INTEGER;
--        BEGIN
--            v_src := l_getcurs;
--            l_ctxId := ExcelGen.createContext();
--            l_sheet_handle := ExcelGen.addSheetFromCursor(l_ctxId, 'DBA Views', v_src, p_tabColor => 'green');
--            BEGIN
--                CLOSE v_src;
--            EXCEPTION WHEN invalid_cursor THEN NULL;
--            END;
--            ExcelGen.setHeader(l_ctxId, l_sheet_handle, p_frozen => TRUE);
--
--            v_email.add_attachment(p_file_name => 'dba_views.xlsx', p_blob_content => ExcelGen.getFileContent(l_ctxId));
--
--            excelGen.closeContext(l_ctxId);
--        END;
--
--        v_email.add_paragraph('The attached spreadsheet should match what is in the html table above');
--        v_email.send;
--    END;
--
-- You have no need to muck with these object attributes directly. Use the methods.
    attachments         arr_email_attachment_udt
    ,arr_to             arr_varchar2_udt
    ,arr_cc             arr_varchar2_udt
    ,arr_bcc            arr_varchar2_udt
    ,from_email_addr    VARCHAR2(4000)
    ,reply_to           VARCHAR2(4000)
    ,smtp_server        VARCHAR2(4000)
    ,subject            VARCHAR2(4000)
    ,body               CLOB]'
$if $$use_app_log $then
||q'[
    ,log                app_log_udt]'
$end
||q'[
    ,CONSTRUCTOR FUNCTION html_email_udt(
        p_to_list           VARCHAR2 DEFAULT NULL
        ,p_cc_list          VARCHAR2 DEFAULT NULL
        ,p_bcc_list         VARCHAR2 DEFAULT NULL
        ,p_from_email_addr  VARCHAR2 DEFAULT '&&from_email_addr'
        ,p_reply_to         VARCHAR2 DEFAULT '&&reply_to'
        ,p_smtp_server      VARCHAR2 DEFAULT '&&smtp_server'
        ,p_subject          VARCHAR2 DEFAULT NULL
        ,p_body             CLOB DEFAULT NULL]'
$if $$use_app_log $then
        ||q'[
        ,p_log              app_log_udt DEFAULT NULL]'
$end
||q'[
    )
        RETURN SELF AS RESULT
    --
    -- best explanation of method chaining rules I found is
    -- https://stevenfeuersteinonplsql.blogspot.com/2019/09/object-type-methods-part-3.html
    --
    ,MEMBER PROCEDURE send(SELF IN html_email_udt) -- cannot be in/out if we allow chaining it.
    ,MEMBER PROCEDURE add_paragraph(SELF IN OUT NOCOPY html_email_udt , p_clob CLOB)
    ,MEMBER FUNCTION  add_paragraph(p_clob CLOB) RETURN html_email_udt
    ,MEMBER PROCEDURE add_to_body(SELF IN OUT NOCOPY html_email_udt, p_clob CLOB)
    ,MEMBER FUNCTION  add_to_body(p_clob CLOB) RETURN html_email_udt
    ,MEMBER PROCEDURE add_table_to_body( -- see cursor_to_table
        SELF IN OUT NOCOPY html_email_udt
        ,p_sql_string   CLOB            := NULL
        ,p_refcursor    SYS_REFCURSOR  := NULL
        ,p_caption      VARCHAR2        := NULL
    )
    ,MEMBER FUNCTION  add_table_to_body( -- see cursor_to_table
        p_sql_string    CLOB            := NULL
        ,p_refcursor    SYS_REFCURSOR  := NULL
        ,p_caption      VARCHAR2        := NULL
    ) RETURN html_email_udt
    -- these take strings that can have multiple comma separated email addresses
    ,MEMBER PROCEDURE add_to(SELF IN OUT NOCOPY html_email_udt, p_to VARCHAR2) 
    ,MEMBER FUNCTION  add_to(p_to VARCHAR2)  RETURN html_email_udt
    ,MEMBER PROCEDURE add_cc(SELF IN OUT NOCOPY html_email_udt, p_cc VARCHAR2)
    ,MEMBER FUNCTION  add_cc(p_cc VARCHAR2) RETURN html_email_udt
    ,MEMBER PROCEDURE add_bcc(SELF IN OUT NOCOPY html_email_udt, p_bcc VARCHAR2)
    ,MEMBER FUNCTION  add_bcc(p_bcc VARCHAR2) RETURN html_email_udt
    ,MEMBER PROCEDURE add_subject(SELF IN OUT NOCOPY html_email_udt, p_subject VARCHAR2)
    ,MEMBER FUNCTION  add_subject(p_subject VARCHAR2) RETURN html_email_udt
    ,MEMBER PROCEDURE add_attachment(
        SELF IN OUT NOCOPY html_email_udt
        ,p_file_name    VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
        -- looks up the mime type from the file_name extension
    )
    ,MEMBER FUNCTION  add_attachment(
        p_file_name     VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
        -- looks up the mime type from the file_name extension
    ) RETURN html_email_udt
    ,MEMBER PROCEDURE add_attachment( -- just in case you need fine control
        SELF IN OUT NOCOPY html_email_udt
        ,p_attachment   email_attachment_udt
    )
    ,MEMBER FUNCTION  add_attachment( -- just in case you need fine control
        p_attachment    email_attachment_udt
    ) RETURN html_email_udt
    --
    -- cursor_to_table() converts either an open sys_refcursor or a SQL query 
    -- string (do not pass both) into an HTML table from the result set of the 
    -- query as a CLOB. By HTML table I mean the partial HTML between 
    -- <table>..</table> inclusive, not the header/body part.
    --
    -- Column value coversions are whatever the database decides, so if you want
    -- to format the results a certain way, do so in the query. Also give 
    -- column aliases for the table column headers to look nice.
    -- Beware to not use spaces in the column name aliases as 
    -- something munges them with _x0020_.
    --
    -- Example:
    --     l_clob := html_email_udt.cursor_to_table(
    --                     p_caption      => 'Payroll Report'
    --                    ,p_sql_string   => q'!
    --                        SELECT
    --                            TO_CHAR(pidm) AS "Employee_PIDM_ID"
    --                            ,TO_CHAR(sum_salary, 'S999,999.99') AS "Salary"
    --                            ,TO_CHAR(payroll_date, 'MM/DD/YYYY') AS "Payroll_Date"
    --                        FROM some_table
    --                    !'
    --              );
    --
    -- You can pass the result to add_to_body() member procedure here, or you 
    -- can use it to construct html separate from this Object. The code is
    -- surprisingly short and sweet, and I pulled it off the interwebs mostly
    -- intact, so feel free to just steal that procedure and use it as you wish.
    --
    --Note: that if the cursor does not return any rows, we silently pass back
    -- a NULL clob
    ,STATIC FUNCTION cursor_to_table(
        -- pass in a string. 
        -- Unfortunately any tables that are not in your schema 
        -- will need to be fully qualified with the schema name. The cursor
        -- version does not share this issue.
        p_sql_string    CLOB            := NULL
        -- pass in an open cursor. This is better for my money.
        ,p_refcursor    SYS_REFCURSOR   := NULL
        -- if provided, will be the caption on the table, generally centered 
        -- on the top of the table by most renderers.
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
    ,STATIC FUNCTION s_split(
         p_s            VARCHAR2
        ,p_separator    VARCHAR2 := ','
    ) RETURN arr_varchar2_udt
);
]'; -- end execute immediate
END; -- end anonymous block
/
show errors
