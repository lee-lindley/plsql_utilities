CREATE OR REPLACE TYPE BODY email_attachment_udt AS
    CONSTRUCTOR FUNCTION email_attachment_udt(
         p_file_name    VARCHAR2
        ,p_clob_content CLOB
        ,p_blob_content BLOB
        ,p_mime_type    VARCHAR2 DEFAULT NULL -- allow constructor to determine
    ) RETURN SELF AS RESULT
    IS
    BEGIN
        IF p_clob_content IS NULL AND p_blob_content IS NULL THEN
            raise_application_error(-20834,'both clob_content and blob_content were null');
        ELSIF p_clob_content IS NOT NULL AND p_blob_content IS NOT NULL THEN
            raise_application_error(-20834,'both clob_content and blob_content were NOT null');
        END IF;
        file_name       := p_file_name;
        clob_content    := p_clob_content;
        blob_content    := p_blob_content;
        IF p_mime_type IS NOT NULL THEN
            mime_type := p_mime_type;
        ELSE
$if $$use_mime_type $then
            mime_type := mime_type_pkg.get(
                p_file_name             => p_file_name
                ,p_use_binary_default   => CASE WHEN p_blob_content IS NOT NULL THEN 'Y' END
            );
$else
            mime_type := CASE WHEN p_blob_content IS NULL THEN 'text/plain' ELSE 'application/octet-stream' END;
$end
        END IF;
        RETURN;
    END;
END;
/
show errors
