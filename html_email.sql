whenever sqlerror exit failure
--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
--
CREATE OR REPLACE PACKAGE html_email AS
    /*
        A set of utilities for generating HTML, specifically for sending email,
        but general purpse as well.

        we can add attachments from CLOBS and/or BLOBS as well as an html body.
    */
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
    -- configuration constants
    --
    c_from_default          CONSTANT VARCHAR2(64) := 'donotreply@bogus.com';
    c_smtp_server_default   CONSTANT VARCHAR2(64) := 'localhost';


    /*
        An structure to be stored in an array that contains an email attachment
        in a clob as well as the filename to suggest when the recipent saves it.
        The filename extension, like '.csv', is used in a table lookup to determine
        the mime type.
    */
    TYPE t_attachment IS RECORD(
         file_name  VARCHAR2(64)
        ,content    CLOB            -- give either clob or blob, not both
        ,bcontent   BLOB
    );
    TYPE t_attachment_list IS TABLE OF t_attachment;

    /*
        get_at() returns an attachment record because assigning to each field in the record
        is sucky syntax. They fix it in Oracle 18 so that you can use same syntax
        as Object constructors, but for now we have to make our own.

        Usage:
            v_attachment_list t_attachment_list := t_attachment_list(
                 html_email.get_at('bogus.csv', my_clob)
                ,html_email.get_at('bogus2.csv', my_clob2)
                ,html_email.get_at('bogus3.xlsx', NULL, my_blob)
            );
    */
    FUNCTION get_at( -- give either clob or blob, not both
         p_file_name    VARCHAR2
        ,p_content      CLOB DEFAULT NULL
        ,p_bcontent     BLOB DEFAULT NULL
    ) RETURN t_attachment;


    /*
        cursor_to_table() converts 
        either an open sys_refcursor or a SQL query string into an HTML table
        from the result set of the query as a CLOB.

        Column value coversions are whatever the database decides, so if you want to format
        the results a certain way, do so in the query. Also give column aliases for the table column
        headers to look nice. Beware to not use spaces in the column name aliases as 
        something munges them.

        Example:
            l_clob := html_email.cursor_to_table(
                             p_caption      => 'Payroll Report'
                            ,p_sql_string   => q'!
                                SELECT
                                    TO_CHAR(pidm) AS "Employee_PIDM_ID"
                                    ,TO_CHAR(sum_salary, 'S999,999.99') AS "Salary"
                                    ,TO_CHAR(payroll_date, 'MM/DD/YYYY') AS "Payroll_Date"
                                FROM some_table
                            !'
                      );

        Note: that if the cursor does not return any rows, we silently pass back an empty clob
    */
    -- pass in a string. 
    -- Unfortunately any tables that are not in your schema 
    -- will need to be fully qualified with the schema name. The open cursor version does
    -- not share this issue.
    FUNCTION cursor_to_table(
        p_sql_string    VARCHAR2
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB;
    -- pass in an open cursor. This is better if you are going to reuse the cursor. See example below
    -- though because reusing the cursor is tricky.
    FUNCTION cursor_to_table(
        p_refcursor     SYS_REFCURSOR
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB;



    /*
        given that you grabbed one or more CLOBs with a HTML tables from queries in them
        OR NOT, then you can create an HTML email including those HTML table clobs,
        building up any html you want.

        Note that you do not put in the <body></body> tags as the procedure will do that.
        The Subject will become the HTML title in the header.

        You can also add CLOB and/or BLOB attachments to the email
        You must pass in an array structure for attachments even if you only have 1.

        The toList, cc_list and bccList strings can contain comma separated list of multiple addresses

        So here is a full example that puts the results of a query both into the body of the email 
        as an HTML table as well as attaching it as a CSV file. 
        That is probably overkill, but this is just an example.

        DECLARE
            v_attach_list   html_email.t_attachment_list; -- an array
            v_src           SYS_REFCURSOR;
            v_html_clob     CLOB;
            v_csv_clob      CLOB;
            -- result_cache hint because we are going to run the query twice in a row. Not necessary,
            -- but some of us always think about efficiency.
            v_query         VARCHAR2(32767) := q'!SELECT --+ RESULT_CACHE 
    al_dedcd                                AS "Deduction_Code"
    ,TO_CHAR(sum_dedcd,'999,999,999.99')    AS "Sum_DEDCD"
    ,TO_CHAR(sum_cmstape,'999,999,999.99')  AS "Sum_CMSTape"
FROM pzbnft_discrepancy
ORDER BY al_dedcd!';
            --
            -- Because you cannot CLOSE/ReOPEN a dynamic sys_refcursor variable directly,
            -- you must regenerate it and assign it. Weird restriction, but do not
            -- try to fight it by opening it in the main code. Get a fresh copy from a function.
            FUNCTION l_getcurs RETURN SYS_REFCURSOR IS
                l_src       SYS_REFCURSOR;
            BEGIN
                OPEN l_src FOR v_query;
                RETURN l_src;
            END;
        BEGIN
            
            -- Get a CLOB with the CSV file content
            v_src := l_getcurs;
            v_csv_clob := csv.get_clob(p_dataset => v_src, p_heading => 'Y');
            -- we need to close it because we are going to open again.
            -- The called package may have closed it, but must be sure or nasty 
            -- bugs/caching can happen.
            BEGIN
                CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
            END;

            -- create the attachment array with one record of filename and CSV clob
            v_attach_list := html_email.t_attachment_list(
                html_email.get_at(
                     p_file_name => 'CMStape_discrepancies'||TO_CHAR(sysdate,'YYYYMMDD')||'.csv'
                    ,p_content   => v_csv_clob
                )
                --, could add more attachments in a list
            );

            DECLARE
                l_xlsx_blob     BLOB;
                l_ctxId         ExcelGen.ctxHandle;
            BEGIN
                l_ctxId := ExcelGen.createContext();
                ExcelGen.addSheetFromQuery(l_ctxId, 'sample query', 'Select sysdate from dual', p_tabColor => 'green');
                ExcelGen.setHeader(l_ctxId, 'sample query', p_frozen => true
                    ,p_style => ExcelGen.makeCellStyle(l_ctxId
                                    ,p_fill => ExcelGen.makePatternFill('solid','LightGray')
                                )
                );
                l_xlsx_blob := ExcelGen.getFileContent(l_ctxId);
                excelGen.closeContext(l_ctxId);

                v_attach_list.EXTEND;
                v_attach_list(v_attach_list.COUNT) := html_email.get_at(
                        p_file_name     => 'A sample spreadsheet.xlsx'
                        ,p_Bcontent     => l_xlsx_blob
                    );
            END;

            -- although we have the attachment csv, this is going to generate an HTML table
            -- that we can include in the body of the email. 
            v_src := l_getcurs; -- need to retrieve a reopened cursor. Just do it.
            -- clob can be NULL if cursor returns no rows!!!!!
            v_html_clob := html_email.cursor_to_table(v_src, 'CMStape Discrepancies');
            BEGIN
                CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
            END;

            -- So now we have an attachment list of csv file/clobs plus an xlsx blob,  and also an HTML table in a clob
            -- (could have more than one, just concatenate them all together in the body, perhaps 
            -- with html text between the tables)
            
            html_email.send_html_email(
                p_toList        => 'lee_spam_this@yahoo.com'
                ,p_subject      => 'CMStape Discrepancy Report for'||TO_CHAR(sysdate,'MM/DD/YYYY')
                ,p_attachments  => v_attach_list
                -- notice how we simply concatenate the html table clob with our other html body text here
                ,p_body         => 
                    '<h1>CMStape Discrepancy Report for '||TO_CHAR(sysdate, 'MM/DD/YYYY')||'</h1>'
                    ||q'!
<p>The report appears in the body of the email as a formatted table, but is also attached
as a comma separted values file that you can open in Excel or google docs.
<p><b>Please be aware of personally identifiable information contained in this email and attachments.</b>
!'
                    ||v_html_clob
            ); -- end send_html_email
        END;
    */
    PROCEDURE send_html_email(
         p_toList       VARCHAR2
        ,p_subject      VARCHAR2
        ,p_body         CLOB    -- do NOT include <body></body> tags
        ,p_ccList       VARCHAR2            := NULL
        ,p_bccList      VARCHAR2            := NULL
        ,p_attachments  t_attachment_list   := NULL
        ,p_from         VARCHAR2            := c_from_default 
        ,p_replyTo      VARCHAR2            := NULL
        ,p_smtp_server  VARCHAR2            := c_smtp_server_default 
$if $$use_app_log $then
        ,p_logger       app_log_udt      := NULL
$end
    );

END html_email
;
/
show errors
CREATE OR REPLACE PACKAGE BODY html_email AS
    
    c_app_name              CONSTANT VARCHAR2(16) := 'send_html_email';
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

    FUNCTION cursor_to_table(
        p_sql_string    VARCHAR2        := NULL
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
        --    GetClobVal from that object which returns a CLOB
        BEGIN
            v_html :=  DBMS_XMLGEN.GETXMLType(v_context, DBMS_XMLGEN.NONE).transform(v_table_xsl).getClobVal();
        EXCEPTION WHEN e_null_object_ref THEN 
            v_html := NULL; -- most likely the cursor returned no rows
$if $$use_app_log $then
            app_log_udt.log_p('html_email', 'cursor_to_table executed cursor that returned no rows. Returning NULL');
$else
            DBMS_OUTPUT.put_line('cursor_to_table executed cursor that returned no rows. Returning NULL');
$end
        END;

        -- it can raise an error easily. Caller should handle.
        RETURN v_html;
    END cursor_to_table;

    -- two variants so can pass either sql string or cursor
    FUNCTION cursor_to_table(
        p_sql_string    VARCHAR2
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
    IS
    BEGIN
        RETURN cursor_to_table(p_sql_string => p_sql_string, p_refcursor => NULL, p_caption => p_caption);
    END cursor_to_table;

    FUNCTION cursor_to_table(
        p_refcursor     SYS_REFCURSOR
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
    IS
    BEGIN
        RETURN cursor_to_table(p_sql_string => NULL, p_refcursor => p_refcursor, p_caption => p_caption);
    END cursor_to_table;


    FUNCTION get_at(
         p_file_name    VARCHAR2
        ,p_content      CLOB DEFAULT NULL
        ,p_bcontent     BLOB DEFAULT NULL
    ) RETURN t_attachment
    IS
        l_attachment    t_attachment;
    BEGIN
        l_attachment.file_name := p_file_name;
        l_attachment.content := p_content;
        l_attachment.bcontent := p_bcontent;
        RETURN l_attachment;
    END get_at;


    PROCEDURE send_html_email(
         p_toList       VARCHAR2
        ,p_subject      VARCHAR2
        ,p_body         CLOB    -- Do NOT put <body></body> around it
        ,p_ccList       VARCHAR2            := NULL
        ,p_bccList      VARCHAR2            := NULL
        ,p_attachments  t_attachment_list   := NULL
        ,p_from         VARCHAR2            := c_from_default 
        ,p_replyTo      VARCHAR2            := NULL
        ,p_smtp_server  VARCHAR2            := c_smtp_server_default 
$if $$use_app_log $then
        ,p_logger       app_log_udt      := NULL
$end
    ) IS
$if $$use_app_log $then
        v_logger        app_log_udt;
$end
        v_smtp          UTL_SMTP.connection;
        v_myhostname    VARCHAR2(255);
        v_to_arr        arr_varchar2_udt;
        v_cc_arr        arr_varchar2_udt;
        v_bcc_arr       arr_varchar2_udt; 
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
$if $$use_app_log $then
        v_logger := NVL(p_logger, app_log_udt(c_app_name));
$end
        IF NOT app_parameter.is_matching_database THEN
$if $$use_app_log $then
            v_logger.log_p('app_parameter.is_matching_database returned FALSE. Will return without sending mail');
$else
            DBMS_OUTPUT.put_line('app_parameter.is_matching_database returned FALSE. Will return without sending mail');
$end
            RETURN;
        END IF;

        v_smtp := UTL_SMTP.open_connection(p_smtp_server, 25);

        -- open the connection to remote mail server and say hello!
        v_myhostname := SYS_CONTEXT('USERENV','SERVER_HOST');
        UTL_SMTP.helo(v_smtp, v_myhostname);
        UTL_SMTP.mail(v_smtp, p_from);
        
        --
        -- tell the remote server about all the rescipients
        --
        v_to_arr := split(p_toList,p_strip_dquote => 'N');
        FOR i IN 1..v_to_arr.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, v_to_arr(i));
        END LOOP;
        v_recipient_count := v_to_arr.COUNT;
        IF p_ccList IS NOT NULL THEN
            v_cc_arr := split(p_ccList,p_strip_dquote => 'N');
            FOR i IN 1..v_cc_arr.COUNT
            LOOP
                UTL_SMTP.rcpt(v_smtp, v_cc_arr(i));
            END LOOP;
            v_recipient_count := v_recipient_count + v_cc_arr.COUNT;
        END IF;
        IF p_bccList IS NOT NULL THEN
            v_bcc_arr := split(p_bccList,p_strip_dquote => 'N');
            FOR i IN 1..v_bcc_arr.COUNT
            LOOP
                UTL_SMTP.rcpt(v_smtp, v_bcc_arr(i));
            END LOOP;
            v_recipient_count := v_recipient_count + v_bcc_arr.COUNT;
        END IF;

        --
        -- Now open for write the main data stream
        --
        UTL_SMTP.open_data(v_smtp);

        --
        -- Now more specific about the recipient being in the From and To lists, but not bcc.
        --
        w('From: '||p_from);

        IF p_replyTo IS NOT NULL THEN
            w('Reply-To:'||p_replyTo);
        END IF;

        FOR i IN 1..v_to_arr.COUNT
        LOOP
            w('To: '||v_to_arr(i));
        END LOOP;

        IF v_cc_arr IS NOT NULL THEN
            FOR i IN 1..v_cc_arr.COUNT
            LOOP
                w('Cc: '||v_cc_arr(i));
            END LOOP;
        END IF;
        
        w('Subject: '||p_subject);

        --
        -- done with preliminary information in the message header. Now we do the multi-part body
        --
        w('MIME-Version: 1.0');
        IF p_attachments IS NULL THEN
            w('Content-Type: multipart/alternative; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        ELSE
            w('Content-Type: multipart/mixed; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        END IF;
        w('--'||c_boundary);
        w('Content-Type: text/html; charset="iso-8859-1"'||UTL_TCP.crlf); -- need extra crlf
        wp('<!doctype html>
<html><head><title>'||p_subject||'</title></head>
<body>');

        --
        -- the clob with the html the caller provided for the body. Use wc cause CLOB needs to be done in chunks
        --
        wc(p_body); 

        w('</body></html>'||UTL_TCP.crlf); -- need extra crlf

        IF p_attachments IS NOT NULL THEN
            FOR i IN 1..p_attachments.COUNT
            LOOP
                w('--'||c_boundary); -- end the last multipart which may have just been the HTML body
                IF p_attachments(i).content IS NOT NULL THEN
                    w('Content-Type: text/plain');
                    w('Content-Transfer-Encoding: text/plain'); -- since it is CLOB, it is char data by definition
                    w('Content-Disposition: attachment; filename="'||p_attachments(i).file_name||'"'||UTL_TCP.crlf); -- extra crlf
                    wc(p_attachments(i).content); -- writes the clob in chunks
                ELSE -- blob instead of clob
                    w('Content-Type: application/octet-stream');
                    w('Content-Transfer-Encoding: base64'); 
                    w('Content-Disposition: attachment; filename="'||p_attachments(i).file_name||'"'||UTL_TCP.crlf); -- extra crlf
                    wb(p_attachments(i).bcontent);
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
        v_logger.log_p('html mail sent to '||TO_CHAR(v_recipient_count)||' recipients'
            ||CASE WHEN p_attachments IS NOT NULL THEN ' with '||TO_CHAR(p_attachments.COUNT)||' attachments' END
        );
$end
        EXCEPTION WHEN OTHERS THEN
$if $$use_app_log $then
            v_logger.log_p('sqlerrm    : '||SQLERRM);
            v_logger.log_p('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            v_logger.log_p('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
$else
            DBMS_OUTPUT.put_line('sqlerrm    : '||SQLERRM);
            DBMS_OUTPUT.put_line('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            DBMS_OUTPUT.put_line('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
$end
            RAISE;

    END send_html_email;
END html_email
;
/
show errors
--ALTER SESSION SET plsql_optimize_level=2;
--ALTER SESSION SET plsql_code_type = INTERPRETED;
-- NOT granting to public. could spam
--GRANT EXECUTE ON html_email TO ???;
