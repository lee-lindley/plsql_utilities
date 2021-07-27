-- REQUIRES: split
--      if you do not want to deploy mine, deploy your own or create a local static function.
-- REQUIRES: arr_varchar2_udt
--      If you have your own you can easily substitute it in the code yourself.
--
-- We optionally use app_parameter and app_log based on compile directives:
--ALTER SESSION SET PLSQL_CCFLAGS='use_app_log:TRUE,use_app_parameter:TRUE';
--
--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
--
/*
    NOTE: you must have priv to write to the network. This is a big subject. 
    Here is what I did as sysdba in order for my account (lee) to be able to write to 
    port 25 on my Oracle server on RHL. Assuming you have an smtp server somewhere
    other than your database server like most sane organizations, you will need 
    the ACL entry for that host and the schema where you are deploying this. 
    If not you will get:

    ORA-24247: network access denied by access control list (ACL)
    
    when you try to send an email. This is true even though we are writing to localhost!

begin
    dbms_network_acl_admin.append_host_ace(
        host => 'localhost'
        ,lower_port => NULL
        ,upper_port => NULL
        ,ace => xs$ace_type(
            privilege_list => xs$name_list('smtp')
            ,principal_name => 'lee'
            ,principal_type => xs_acl.ptype_db
        )
    );
end;
-- the slash goes here
*/
whenever sqlerror continue
-- the attachment type has a dependency
DROP TYPE html_email_udt;
prompt ok if type drop failed for not exists
DROP TYPE arr_html_email_attachment_udt;
prompt ok if type drop failed for not exists
whenever sqlerror exit failure
CREATE OR REPLACE TYPE html_email_attachment_udt AS OBJECT (
         file_name      VARCHAR2(64)
        ,clob_content   CLOB            -- give either clob or blob, not both
        ,blob_content   BLOB
);
/
show errors
CREATE OR REPLACE TYPE arr_html_email_attachment_udt AS TABLE OF html_email_attachment_udt;
/
show errors
--
-- oh my, how embarrasing for Oracle. You cannot use compile directives in the definition
-- of a user defined type object. You can use them just fine in the body, but not in
-- creating the type itself (type specification). In any case we must use the preprocessor directives
-- to create a character string that we feed to execute immediate. We apply the preprocessor directives
-- in the anonymous block that builds the string. Such a damn hack. Shame Oracle! Shame!
-- At least the hack is only for deployment code. I can live with it.
--
BEGIN
EXECUTE IMMEDIATE q'[
CREATE OR REPLACE TYPE html_email_udt AS OBJECT (
    /*
        An object for creating and sending an email message with an HTML
        body and optional attachments.
        A utility static function can return an HTML table from a query string or cursor
        for general use in addition to adding it to an email body.
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
--    Here is an example that puts the results of a query both into the body of the email 
--    as an HTML table as well as attaching it as an XLSX file. 
--    That is probably overkill, but this is just an example.
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
--            ,p_from_email_addr  => 'myname@myhost'
--            ,p_reply_to         => 'donotreply@nohost'
--            ,p_subject          => 'A sample email from html_email_udt'
--        );
--        v_email.add_paragraph('We constructed and sent this email with html_email_udt.');
--        v_src := l_getcurs;
--        v_email.add_to_body(html_email_udt.cursor_to_table(p_refcursor => v_src, p_caption => 'DBA Views'));
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
--            v_email.add_attachment(p_file_name => 'dba_views.xlsx', p_blob_content => ExcelGen.getFileContent(l_ctxId));
--            excelGen.closeContext(l_ctxId);
--        END;
--        v_email.add_paragraph('The attached spreadsheet should match what is in the html table above');
--        v_email.send;
--    END;
--
    attachments         arr_html_email_attachment_udt
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
        p_to_list           CLOB DEFAULT NULL
        ,p_cc_list          CLOB DEFAULT NULL
        ,p_bcc_list         CLOB DEFAULT NULL
        ,p_from_email_addr  VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_reply_to         VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_smtp_server      VARCHAR2 DEFAULT 'localhost'
        ,p_subject          VARCHAR2 DEFAULT NULL
        ,p_body             CLOB DEFAULT NULL]'
$if $$use_app_log $then
        ||q'[
        ,p_log              app_log_udt DEFAULT NULL]'
$end
||q'[
    )
        RETURN SELF AS RESULT
    ,MEMBER PROCEDURE send
    ,MEMBER PROCEDURE add_paragraph(p_clob CLOB)
    ,MEMBER PROCEDURE add_to_body(p_clob CLOB)
    ,MEMBER PROCEDURE add_to(p_to VARCHAR2) 
    ,MEMBER PROCEDURE add_cc(p_cc VARCHAR2)
    ,MEMBER PROCEDURE add_bcc(p_bcc VARCHAR2)
    ,MEMBER PROCEDURE add_subject(p_subject VARCHAR2)
    ,MEMBER PROCEDURE add_attachment(
        p_file_name     VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
    )
    --
    -- cursor_to_table() converts 
    -- either an open sys_refcursor or a SQL query string (do not pass both) into an HTML table
    -- from the result set of the query as a CLOB. By HTML table I mean the partial
    -- HTML between <table>..</table> inclusive, not the header/body part.
    --
    -- Column value coversions are whatever the database decides, so if you want to format
    -- the results a certain way, do so in the query. Also give column aliases for the table column
    -- headers to look nice. Beware to not use spaces in the column name aliases as 
    -- something munges them with %020.
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
    -- You can pass the result to add_to_body() member procedure here, or you can use 
    -- it to construct html separate from this Object. The code is surprisingly
    -- short and sweet, and I pulled it off the interwebs mostly intact, so feel 
    -- free to just steal that procedure and use it as you wish.
    --
    --Note: that if the cursor does not return any rows, we silently pass back an empty clob
    ,STATIC FUNCTION cursor_to_table(
        -- pass in a string. 
        -- Unfortunately any tables that are not in your schema 
        -- will need to be fully qualified with the schema name. The open cursor version does
        -- not share this issue.
        p_sql_string    CLOB            := NULL
        -- pass in an open cursor. This is better for my money.
        ,p_refcursor     SYS_REFCURSOR  := NULL
        -- if provided, will be the caption on the table, generally centered on the top of it
        -- by most renderers.
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
);
]';
END;
/
CREATE OR REPLACE TYPE BODY html_email_udt AS

    CONSTRUCTOR FUNCTION html_email_udt(
        p_to_list           CLOB DEFAULT NULL
        ,p_cc_list          CLOB DEFAULT NULL
        ,p_bcc_list         CLOB DEFAULT NULL
        ,p_from_email_addr  VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_reply_to         VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_smtp_server      VARCHAR2 DEFAULT 'localhost'
        ,p_subject          VARCHAR2 DEFAULT NULL
        ,p_body             CLOB DEFAULT NULL
$if $$use_app_log $then
        ,p_log              app_log_udt DEFAULT NULL
$end
    )
    RETURN SELF AS RESULT
    IS
    BEGIN
        arr_to := split(p_to_list,p_strip_dquote => 'N');
        arr_cc := split(p_cc_list,p_strip_dquote => 'N');
        arr_bcc := split(p_bcc_list,p_strip_dquote => 'N');
        from_email_addr := p_from_email_addr;
        reply_to := p_reply_to;
        smtp_server := p_smtp_server;
        subject := p_subject;
        body := p_body;
        attachments := arr_html_email_attachment_udt();
$if $$use_app_log $then
        log := NVL(p_log, app_log_udt('HTML_EMAIL_UDT'));
$end
        RETURN;
    END 
    ; -- end constructor html_email_udt
    MEMBER PROCEDURE add_to_body(p_clob CLOB)
    IS
    BEGIN
        body := body||p_clob;
    END; -- end add_to_body

    -- feel a bit silly with this since everyone should know enough html to do manually
    MEMBER PROCEDURE add_paragraph(p_clob CLOB)
    IS
    BEGIN
        IF body IS NULL THEN
            body := '<p>'||p_clob;
        ELSE
            body := body||'<br><br><p>'||p_clob;
        END IF;
    END; -- add_paragraph

    MEMBER PROCEDURE add_to(p_to VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := split(p_to, p_strip_dquote => 'N');
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_to.EXTEND;
            arr_to(arr_to.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_to


    MEMBER PROCEDURE add_cc(p_cc VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := split(p_cc, p_strip_dquote => 'N');
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_cc.EXTEND;
            arr_cc(arr_cc.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_cc

    MEMBER PROCEDURE add_bcc(p_bcc VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := split(p_bcc, p_strip_dquote => 'N');
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_bcc.EXTEND;
            arr_bcc(arr_bcc.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_bcc

    MEMBER PROCEDURE add_subject(p_subject VARCHAR2)
    IS
    BEGIN
        subject := p_subject;
    END;

    MEMBER PROCEDURE add_attachment(
        p_file_name     VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
    )
    IS
    BEGIN
        IF p_clob_content IS NULL AND p_blob_content IS NULL THEN
            raise_application_error(-20834,'both p_clob_content and p_blob_content in call to add_attachment were null');
        ELSIF p_clob_content IS NOT NULL AND p_blob_content IS NOT NULL THEN
            raise_application_error(-20834,'both p_clob_content and p_blob_content in call to add_attachment were NOT null');
        END IF;
        attachments.EXTEND;
        attachments(attachments.COUNT) := html_email_attachment_udt(
            p_file_name
            ,p_clob_content
            ,p_blob_content
        );
    END; -- end add_attachment



    STATIC FUNCTION cursor_to_table(
        p_sql_string    CLOB            := NULL -- either the CLOB or the cursor must be null
        ,p_refcursor    SYS_REFCURSOR   := NULL
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
    IS
        v_context       DBMS_XMLGEN.CTXHANDLE;
        v_table_xsl     XMLType;
        v_html          CLOB;

        invalid_arguments       EXCEPTION;
        PRAGMA exception_init(invalid_arguments, -20881);
        e_null_object_ref       EXCEPTION;
        PRAGMA exception_init(e_null_object_ref, -30625);

        -- 
        -- stylesheets and xml transforms are not something I really studied.
        -- this is cookie cutter code I got off the web
        -- The token __CAPTION__ is optionally replace by a title/caption for the top of the table
        -- 
        c_xsl CONSTANT VARCHAR2(1024) := q'!<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="html"/>
 <xsl:template match="/">
   <table border="1"> __CAPTION__
    <tr>
     <xsl:for-each select="/ROWSET/ROW[1]/*">
      <th><xsl:value-of select="name()"/></th>
     </xsl:for-each>
    </tr>
    <xsl:for-each select="/ROWSET/*">
    <tr>    
     <xsl:for-each select="./*">
      <td><xsl:value-of select="text()"/> </td>
     </xsl:for-each>
    </tr>
   </xsl:for-each>
  </table>
 </xsl:template>
</xsl:stylesheet>!';

    BEGIN

        IF p_refcursor IS NOT NULL THEN
            v_context := DBMS_XMLGEN.NEWCONTEXT(p_refcursor);
        ELSIF p_sql_string IS NOT NULL THEN
            v_context := DBMS_XMLGEN.NEWCONTEXT(p_sql_string);
        ELSE
            raise_application_error(-20881,'both p_sql_string and p_refcursor were null');
        END IF;
        -- set to 1 for xsi:nil="true"
        DBMS_XMLGEN.setNullHandling(v_context,1);

        IF p_caption IS NULL
        THEN
            v_table_xsl := XMLTYPE(regexp_replace(c_xsl, '__CAPTION__', ''));
        ELSE
            v_table_xsl := XMLType(regexp_replace(c_xsl, '__CAPTION__', '<caption>'||p_caption||'</caption>'));
        END IF;
        -- so we have a context that contains an open cursor and we have an xsl style sheet to 
        -- be used to transform it. Sequence here is
        -- 1) Get an XMLType object from the context.
        -- 2) Call the transform method of that XMLType object instance passing the XSL XMLType object
        --    as an argument.
        -- 3) The result of the transform method is yet another XMLType object. Call the method
        --    getClobVal from that object which returns a CLOB
        BEGIN
            v_html :=  DBMS_XMLGEN.GETXMLType(v_context, DBMS_XMLGEN.NONE).transform(v_table_xsl).getClobVal();
        EXCEPTION WHEN e_null_object_ref THEN 
            v_html := NULL; -- most likely the cursor returned no rows
$if $$use_app_log $then
            app_log_udt.log_p('html_email_udt', 'cursor_to_table executed cursor that returned no rows. Returning NULL');
$else
            DBMS_OUTPUT.put_line('cursor_to_table executed cursor that returned no rows. Returning NULL');
$end
        END;
        -- it can easily raise a different error than we trapped. Caller should handle.
        RETURN v_html;
    END cursor_to_table;

    MEMBER PROCEDURE send 
    IS
        v_smtp          UTL_SMTP.connection;
        v_myhostname    VARCHAR2(255);
        v_recipient_count   BINARY_INTEGER;

        c_chunk_size    CONSTANT INTEGER := 57;
        c_boundary      CONSTANT VARCHAR2(50) := '---=*jkal8KKzbrgLN24z#wq*=';

        --
        -- convenience procedures rather than spelling everything out each time we 
        -- write to the SMTP connection
        --
        -- w for write varchar with crlf
        PROCEDURE w(l_v VARCHAR2) IS
        BEGIN
            UTL_SMTP.write_data(v_smtp, l_v||UTL_TCP.crlf);
        END;
        -- wp for write plain varchar w/o crlf added
        PROCEDURE wp(l_v VARCHAR2) IS
        BEGIN
            UTL_SMTP.write_data(v_smtp, l_v);
        END;
        -- write clob. UTL_SMTP takes varchar and apparently some reason everyone sends chunks of 57 bytes
        -- at least on attachments. Might as well for html clob in the main body too
        -- https://oracle-base.com/articles/misc/email-from-oracle-plsql#attachment
        PROCEDURE wc(l_c CLOB) IS
        BEGIN
            FOR j IN 0..TRUNC((DBMS_LOB.getlength(l_c) - 1) / c_chunk_size)
            LOOP
                -- do not throw cr/lf in the middle of this, so wp for write plain!!!
                -- subst returns varchar2, so wp handles fine
                wp(DBMS_LOB.substr(lob_loc => l_c
                                    ,amount => c_chunk_size
                                    ,offset => (j * c_chunk_size) + 1
                    ) 
                );
            END LOOP; -- end for the chunks this attachment
            w(UTL_TCP.crlf); -- two crlf after clob attachment
        END;

        -- https://oracle-base.com/articles/misc/email-from-oracle-plsql#attachment
        PROCEDURE wb(l_b BLOB) IS
        BEGIN
            FOR j IN 0..TRUNC((DBMS_LOB.getlength(l_b) - 1) / c_chunk_size)
            LOOP
                UTL_SMTP.write_data(v_smtp
                    ,UTL_RAW.cast_to_varchar2(
                        UTL_ENCODE.base64_encode(
                            DBMS_LOB.substr(lob_loc => l_b
                                            ,amount => c_chunk_size
                                            ,offset => (j * c_chunk_size) + 1
                            )
                        )
                     )|| UTL_TCP.crlf -- a crlf after every chunk!!!
                );
            END LOOP;
            UTL_SMTP.write_data(v_smtp, UTL_TCP.crlf); -- write one more crlf after blob attachment
        END;
--
-- start main procedure body
--
    BEGIN
$if $$use_app_parameter $then
        IF NOT app_parameter.is_matching_database THEN
            -- This is the scenario that we are a database cloned from production and
            -- if we run using the parameters containing production email addresses,
            -- we are going to spam our business users and partners from our test
            -- region. This check will prevent that and give us a chance to update 
            -- the parameters for this database region.
    $if $$use_app_log $then
            log.log_p('app_parameter.is_matching_database returned FALSE. Will return without sending mail');
    $else
            DBMS_OUTPUT.put_line('app_parameter.is_matching_database returned FALSE. Will return without sending mail');
    $end
            RETURN;
        END IF;
$end
        IF arr_to.COUNT + arr_cc.COUNT + arr_bcc.COUNT = 0 THEN
            raise_application_error(-20835,'no recipients were provided before calling html_email_udt.send');
        END IF;

        v_smtp := UTL_SMTP.open_connection(smtp_server, 25);

        -- open the connection to remote (or local) mail server and say hello!
        v_myhostname := SYS_CONTEXT('USERENV','SERVER_HOST');
        UTL_SMTP.helo(v_smtp, v_myhostname);
        UTL_SMTP.mail(v_smtp, from_email_addr);
        
        --
        -- tell the remote server about all the rescipients
        --
        FOR i IN 1..arr_to.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_to(i));
        END LOOP;
        v_recipient_count := arr_to.COUNT;
        FOR i IN 1..arr_cc.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_cc(i));
        END LOOP;
        v_recipient_count := v_recipient_count + arr_cc.COUNT;
        FOR i IN 1..arr_bcc.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_bcc(i));
        END LOOP;
        v_recipient_count := v_recipient_count + arr_bcc.COUNT;

        --
        -- Now open for write the main data stream
        --
        UTL_SMTP.open_data(v_smtp);

        --
        -- Now more specific about the recipient being in the From and To lists, but not bcc.
        --
        w('From: '||from_email_addr);

        IF reply_to IS NOT NULL THEN
            w('Reply-To:'||reply_to);
        END IF;

        FOR i IN 1..arr_to.COUNT
        LOOP
            w('To: '||arr_to(i));
        END LOOP;

        FOR i IN 1..arr_cc.COUNT
        LOOP
            w('Cc: '||arr_cc(i));
        END LOOP;
        
        w('Subject: '||subject);

        --
        -- done with preliminary information in the message header. Now we do the multi-part body
        --
        w('MIME-Version: 1.0');
        IF attachments.COUNT = 0 THEN
            w('Content-Type: multipart/alternative; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        ELSE
            w('Content-Type: multipart/mixed; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        END IF;
        w('--'||c_boundary);
        w('Content-Type: text/html; charset="iso-8859-1"'||UTL_TCP.crlf); -- need extra crlf
        wp('<!doctype html>
<html><head><title>'||subject||'</title></head>
<body>');
        --
        -- the clob with the html the caller provided for the body. Use wc because CLOB needs to be done in chunks
        --
        wc(body); 

        -- finish off the html and pad the end of the "part" with line endings per the rules
        w('</body></html>'||UTL_TCP.crlf); -- need extra crlf

        IF attachments.COUNT > 0 THEN
            FOR i IN 1..attachments.COUNT
            LOOP
                w('--'||c_boundary); -- end the last multipart which may have just been the HTML document
                IF attachments(i).clob_content IS NOT NULL THEN
                    w('Content-Type: text/plain');
                    w('Content-Transfer-Encoding: text/plain'); -- since it is CLOB, it is char data by definition
                    w('Content-Disposition: attachment; filename="'||attachments(i).file_name||'"'||UTL_TCP.crlf); -- extra crlf
                    wc(attachments(i).clob_content); -- writes the clob in chunks
                ELSE -- blob instead of clob
                    w('Content-Type: application/octet-stream');
                    w('Content-Transfer-Encoding: base64'); 
                    w('Content-Disposition: attachment; filename="'||attachments(i).file_name||'"'||UTL_TCP.crlf); -- extra crlf
                    wb(attachments(i).blob_content);
                END IF;
            END LOOP; -- end foreach attachment
        END IF;

        -- final boundary closes out the mail body whether last thing written was the html message part
        -- or an attachment part. trailing '--' seals the deal.
        w('--'||c_boundary||'--'); 

        -- Now hang up the connection
        UTL_SMTP.close_data(v_smtp);
        UTL_SMTP.quit(v_smtp);

$if $$use_app_log $then
        log.log_p('html mail sent to '||TO_CHAR(v_recipient_count)||' recipients'
            ||CASE WHEN attachments.COUNT > 0 THEN ' with '||TO_CHAR(attachments.COUNT)||' attachments' END
        );
$end
        EXCEPTION WHEN OTHERS THEN
$if $$use_app_log $then
            log.log_p('sqlerrm    : '||SQLERRM);
            log.log_p('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            log.log_p('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
$else
            DBMS_OUTPUT.put_line('sqlerrm    : '||SQLERRM);
            DBMS_OUTPUT.put_line('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            DBMS_OUTPUT.put_line('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
$end
            RAISE;

    END; -- send
END;
/
show errors
--ALTER SESSION SET plsql_optimize_level=2;
--ALTER SESSION SET plsql_code_type = INTERPRETED;
-- NOT granting to public. could spam
--GRANT EXECUTE ON html_email_udt TO ???;
