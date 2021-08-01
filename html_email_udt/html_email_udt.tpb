CREATE OR REPLACE TYPE BODY html_email_udt AS

    CONSTRUCTOR FUNCTION html_email_udt(
        p_to_list           VARCHAR2 DEFAULT NULL
        ,p_cc_list          VARCHAR2 DEFAULT NULL
        ,p_bcc_list         VARCHAR2 DEFAULT NULL
        ,p_from_email_addr  VARCHAR2 DEFAULT '&&from_email_addr'
        ,p_reply_to         VARCHAR2 DEFAULT '&&reply_to'
        ,p_smtp_server      VARCHAR2 DEFAULT '&&smtp_server'
        ,p_subject          VARCHAR2 DEFAULT NULL
        ,p_body             CLOB DEFAULT NULL
$if $$use_app_log $then
        ,p_log              app_log_udt DEFAULT NULL
$end
    )
    RETURN SELF AS RESULT
    IS
    BEGIN
        -- split will return an initialized, empty collection object if the 
        -- input string is null
        arr_to          := html_email_udt.s_split(p_to_list);
        arr_cc          := html_email_udt.s_split(p_cc_list);
        arr_bcc         := html_email_udt.s_split(p_bcc_list);
        from_email_addr := p_from_email_addr;
        reply_to        := p_reply_to;
        smtp_server     := p_smtp_server;
        subject         := p_subject;
        body            := p_body;
        attachments     := arr_email_attachment_udt();
$if $$use_app_log $then
        log             := NVL(p_log, app_log_udt('HTML_EMAIL_UDT'));
$end
        RETURN;
    END; -- end constructor html_email_udt

    STATIC FUNCTION s_split(
        p_s             VARCHAR2
        ,p_separator    VARCHAR2 := ','
    ) RETURN arr_varchar2_udt
    IS
$if $$use_split $then
    BEGIN
        RETURN split(p_s => p_s, p_separator => p_separator, p_strip_dquote => 'N');
$else
        v_str       VARCHAR2(4000);
        v_a         arr_varchar2_udt := arr_varchar2_udt();
        v_occurence BINARY_INTEGER := 1;
    BEGIN
        LOOP
            --
            -- a little trickiness with regexp
            -- The pattern starts with "([^,]+)" meaning we CAPTURE the string that does not have any 
            -- comma chars in it. That syntax with the + means we need one or more not-comma chars
            -- Then we match ",?" which is 0 or 1 of the delimiter chars (comma in this case). 
            -- The delimiter (comma) is not the capture part so not returned in v_str, 
            -- but the delimiter IS  skipped to reposition us for the next "occurrence" search.
            -- Note that the ? (0 or 1) thingie means we will match the last address in the string too because
            -- we do not have to have a delimiter at the end or maybe no delimiters at all. So this will match
            -- all of (a,b,c) and (a,b,c,) and (a) or (a,) giving us 3, 3, 1, and 1 entries in the array.
            --
            v_str := REGEXP_SUBSTR(p_s, '([^'||p_separator||']+)'||p_separator||'?', 1, v_occurence, '', 1);
            EXIT WHEN v_str IS NULL;
            v_a.EXTEND;
            v_a(v_a.COUNT) := TRIM(v_str);
            v_occurence := v_occurence + 1; -- keep track of where we are in the string
        END LOOP;
        RETURN v_a;      
$end
    END;

    MEMBER PROCEDURE add_to_body(SELF IN OUT NOCOPY html_email_udt, p_clob CLOB)
    IS
    BEGIN
        body := body||p_clob;
    END; -- end add_to_body
    MEMBER FUNCTION add_to_body(p_clob CLOB) RETURN html_email_udt
    IS -- incoming object SELF is read only variable. We MUST make a copy to be able to modify and return it
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_to_body(p_clob);
        RETURN l_self;
    END; -- end add_to_body

    -- feel a bit silly with this since everyone should know enough html to do
    -- manually
    MEMBER PROCEDURE add_paragraph(SELF IN OUT NOCOPY html_email_udt, p_clob CLOB)
    IS
    BEGIN
        IF body IS NULL THEN
            body := '<p>'||p_clob;
        ELSE
            body := body||'<br>
<br><p>'
                        ||p_clob;
        END IF;
    END; -- add_paragraph
    MEMBER FUNCTION add_paragraph(p_clob CLOB) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_paragraph(p_clob);
        RETURN l_self;
    END; -- add_paragraph


    MEMBER PROCEDURE add_to(SELF IN OUT NOCOPY html_email_udt, p_to VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := html_email_udt.s_split(p_to);
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_to.EXTEND;
            arr_to(arr_to.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_to
    MEMBER FUNCTION add_to(p_to VARCHAR2) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_to(p_to);
        RETURN l_self;
    END; -- end add_to


    MEMBER PROCEDURE add_cc(p_cc VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := html_email_udt.s_split(p_cc);
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_cc.EXTEND;
            arr_cc(arr_cc.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_cc
    MEMBER FUNCTION add_cc(p_cc VARCHAR2) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_cc(p_cc);
        RETURN l_self;
    END; -- end add_cc

    MEMBER PROCEDURE add_bcc(SELF IN OUT NOCOPY html_email_udt, p_bcc VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := html_email_udt.s_split(p_bcc);
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_bcc.EXTEND;
            arr_bcc(arr_bcc.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_bcc
    MEMBER FUNCTION add_bcc(p_bcc VARCHAR2) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_bcc(p_bcc);
        RETURN l_self;
    END; -- end add_bcc

    MEMBER PROCEDURE add_subject(SELF IN OUT NOCOPY html_email_udt, p_subject VARCHAR2)
    IS
    BEGIN
        subject := p_subject;
    END;
    MEMBER FUNCTION add_subject(p_subject VARCHAR2) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_subject(p_subject);
        RETURN l_self;
    END;

    MEMBER PROCEDURE add_attachment(
        SELF IN OUT NOCOPY html_email_udt
        ,p_file_name    VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
    )
    IS
    BEGIN
        add_attachment(
            email_attachment_udt(
                p_file_name
                ,p_clob_content
                ,p_blob_content
            )
        );
    END; -- end add_attachment
    MEMBER FUNCTION add_attachment(
        p_file_name     VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
    ) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_attachment(p_file_name, p_clob_content, p_blob_content);
        RETURN l_self;
    END; -- end add_attachment

    MEMBER PROCEDURE add_attachment( 
        SELF IN OUT NOCOPY html_email_udt
        ,p_attachment   email_attachment_udt
    ) IS
    BEGIN
        IF p_attachment.clob_content IS NULL AND p_attachment.blob_content IS NULL THEN
            raise_application_error(-20834,'both clob_content and blob_content in call to add_attachment were null');
        ELSIF p_attachment.clob_content IS NOT NULL AND p_attachment.blob_content IS NOT NULL THEN
            raise_application_error(-20834,'both clob_content and blob_content in call to add_attachment were NOT null');
        END IF;
        IF p_attachment.mime_type IS NULL THEN -- user would have to TRY to get this condition
            raise_application_error(-20834,'attachment mime_type cannot be null');
        END IF;
        attachments.EXTEND;
        attachments(attachments.COUNT) := p_attachment;
    END;
    MEMBER FUNCTION add_attachment( 
        p_attachment    email_attachment_udt
    ) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_attachment(p_attachment);
        RETURN l_self;
    END;

    MEMBER PROCEDURE add_table_to_body( -- see cursor_to_table
        SELF IN OUT NOCOPY html_email_udt
        ,p_sql_string   CLOB            := NULL
        ,p_refcursor    SYS_REFCURSOR   := NULL
        ,p_caption      VARCHAR2        := NULL
    ) IS
    BEGIN
        body := body||'<br>
<br>'
            ||html_email_udt.cursor_to_table(
                p_sql_string    => p_sql_string
                ,p_refcursor    => p_refcursor
                ,p_caption      => p_caption
              );
    END; -- end add_table_to_body
    MEMBER FUNCTION add_table_to_body( -- see cursor_to_table
        p_sql_string    CLOB            := NULL
        ,p_refcursor    SYS_REFCURSOR   := NULL
        ,p_caption      VARCHAR2        := NULL
    ) RETURN html_email_udt
    IS
        l_self  html_email_udt := SELF;
    BEGIN
        l_self.add_table_to_body(p_sql_string, p_refcursor, p_caption);
        RETURN l_self;
    END; -- end add_table_to_body

    STATIC FUNCTION cursor_to_table(
        -- either the CLOB or the cursor must be null
        p_sql_string    CLOB            := NULL 
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
        -- The token __CAPTION__ is optionally replace by a title/caption for
        -- the top of the table
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
        -- we have a context that contains an open cursor and we have an xsl 
        -- style sheet to transform it. Sequence here is
        --     1) Get an XMLType object from the context.
        --     2) Call the transform method of that XMLType object instance
        --          passing the XSL XMLType object as an argument.
        --     3) The result of the transform method is yet another XMLType
        --        object. Call the method getClobVal() from that object which
        --        returns a CLOB
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
        -- it can easily raise a different error than we trapped.
        -- Caller should handle exceptions as appropriate.
        RETURN v_html;
    END cursor_to_table;

    MEMBER PROCEDURE send(SELF IN html_email_udt) -- so it can be chained
    IS
        v_smtp              UTL_SMTP.connection;
        v_myhostname        VARCHAR2(255);

        c_chunk_size        CONSTANT INTEGER := 57;
        c_boundary          CONSTANT VARCHAR2(50) := '---=*jkal8KKzbrgLN24z#wq*=';

$if $$use_app_log $then
        -- because we are not in/out, we must make a copy of either SELF
        -- or any object members we intend to use to invoke methods. Obscure consequence
        -- of wanting to make this procedure able to be on the end of a chain
        -- of method calls.
        v_log   app_log_udt := log;
$end
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
        -- write clob. UTL_SMTP takes varchar and apparently some reason
        -- everyone sends chunks of 57 bytes at least on attachments. Might 
        -- as well for html clob in the main body too
        -- https://oracle-base.com/articles/misc/email-from-oracle-plsql#attachment
        PROCEDURE wc(l_c CLOB) IS
        BEGIN
            FOR j IN 0..TRUNC((DBMS_LOB.getlength(l_c) - 1) / c_chunk_size)
            LOOP
                -- do not throw cr/lf in the middle of this, so wp for
                -- write plain!!!  substr returns varchar2, so wp() handles fine
                wp(DBMS_LOB.substr(lob_loc => l_c
                                    ,amount => c_chunk_size
                                    ,offset => (j * c_chunk_size) + 1
                    ) 
                );
            END LOOP; -- end for the chunks this attachment
            w(UTL_TCP.crlf); -- two crlf after clob attachment
        END;

        -- write blob.
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
            -- This is the scenario that we are a database cloned from 
            -- production and if we run using the parameters containing 
            -- production email addresses, we are going to spam our business 
            -- users and partners from our test region. This check will prevent
            -- that and give us a chance to update the parameters for this 
            -- database region.
    $if $$use_app_log $then
            v_log.log_p('app_parameter.is_matching_database returned FALSE. Will return without sending mail');
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
        -- tell the server about all the recipients
        --
        FOR i IN 1..arr_to.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_to(i));
        END LOOP;
        FOR i IN 1..arr_cc.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_cc(i));
        END LOOP;
        FOR i IN 1..arr_bcc.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_bcc(i));
        END LOOP;

        --
        -- Now open for write the main data stream
        --
        UTL_SMTP.open_data(v_smtp);

        --
        -- recipients in the From and To lists, but not bcc.
        -- get to be visible in the email.
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
        -- done with preliminary information in the message header.
        -- Now we do the multi-part body where the message itself
        -- being HTML is a part.
        --
        w('MIME-Version: 1.0');
        IF attachments.COUNT = 0 THEN
            w('Content-Type: multipart/alternative; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        ELSE
            w('Content-Type: multipart/mixed; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        END IF;
        w('--'||c_boundary);
        -- first part is the html email body
        w('Content-Type: text/html; charset="iso-8859-1"'||UTL_TCP.crlf); -- need extra crlf
        -- we generate the html/head/title/body tags for our document.
        -- Our inputs will be the middle of the html document.
        wp('<!doctype html>
<html><head><title>'||subject||'</title></head>
<body>');
        --
        -- the clob with the html the caller provided for the body, either
        -- all at once or by calling methods we provided to add pieces. Use wc()
        -- because CLOB needs to be done in chunks
        --
        wc(body); 

        -- finish off the html and pad the end of the "part" with line endings 
        -- per the rules
        w('</body></html>'||UTL_TCP.crlf); -- need extra crlf

        IF attachments.COUNT > 0 THEN
            FOR i IN 1..attachments.COUNT
            LOOP
                w('--'||c_boundary); -- end the last multipart which may have
                                     -- just been the HTML document
                w('Content-Type: '||attachments(i).mime_type);
                IF attachments(i).clob_content IS NOT NULL THEN
                    --w('Content-Type: text/plain');
                    -- since it is CLOB, it is char data by definition.
                    w('Content-Transfer-Encoding: text/plain'); 
                    w('Content-Disposition: attachment; filename="'||attachments(i).file_name||'"'||UTL_TCP.crlf); -- extra crlf
                    wc(attachments(i).clob_content); -- writes the clob in chunks
                ELSE -- blob instead of clob
                    --w('Content-Type: application/octet-stream');
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
        v_log.log_p('html mail sent to '||TO_CHAR(arr_to.COUNT + arr_cc.COUNT + arr_bcc.COUNT)
                        ||' recipients'
                        ||CASE WHEN attachments.COUNT > 0 
                               THEN ' with '||TO_CHAR(attachments.COUNT)||' attachments' 
                          END
        );
$end
        EXCEPTION WHEN OTHERS THEN
$if $$use_app_log $then
            v_log.log_p('sqlerrm    : '||SQLERRM);
            v_log.log_p('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            v_log.log_p('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
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
