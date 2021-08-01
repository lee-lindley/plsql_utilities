CREATE OR REPLACE PACKAGE app_lob
AUTHID CURRENT_USER
IS
/*
    This is all code you can find on the web or even in the Oracle documentation.
    Seems like Oracle should have put these in DBMS_LOB.
    I will not be so silly as to copyright or license it.
*/
    PROCEDURE blob_to_file(
        p_filename                 VARCHAR2
        ,p_directory                VARCHAR2
        ,p_blob                     BLOB
$if $$use_app_log $then
        ,p_logger                   app_log_udt DEFAULT NULL -- we can use yours if you want the messages to have your applicaton id
$end
    );

    FUNCTION clob_to_blob(
         p_data                     CLOB
$if $$use_app_log $then
         ,p_logger                  app_log_udt DEFAULT NULL
$end
    ) RETURN BLOB
    ;

    FUNCTION file_to_blob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
$if $$use_app_log $then
        ,p_logger                   app_log_udt DEFAULT NULL -- we can use yours if you want the messages to have your applicaton id
$end
    ) RETURN BLOB
    ;

END app_lob;
/
show errors
