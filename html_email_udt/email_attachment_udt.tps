CREATE OR REPLACE TYPE email_attachment_udt AS OBJECT (
     file_name      VARCHAR2(64)
    ,clob_content   CLOB            -- give either clob or blob, not both
    ,blob_content   BLOB
    ,mime_type      VARCHAR2(120)
    ,CONSTRUCTOR FUNCTION email_attachment_udt(
         p_file_name    VARCHAR2
        ,p_clob_content CLOB
        ,p_blob_content BLOB
        ,p_mime_type    VARCHAR2 DEFAULT NULL -- allow constructor to determine
    ) RETURN SELF AS RESULT
);
/
show errors
