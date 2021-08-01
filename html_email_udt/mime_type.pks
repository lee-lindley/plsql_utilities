BEGIN
    -- we use a trick with anonymous block and plsql compile directives
    -- to determine whether or not to deploy package mime_type
$if $$use_mime_type $then
    EXECUTE IMMEDIATE q'[
CREATE OR REPLACE PACKAGE mime_type_pkg IS
    FUNCTION get(
        p_file_name             VARCHAR2
        ,p_use_binary_default   VARCHAR2 := NULL -- Y or not Y
    ) RETURN VARCHAR2;
    -- can provide extension with no dot, .extension, or full filename
    -- if extension not found or there is not one in your file name
    -- will return text/plain (or application/octet-stream if use_binary=Y)
END mime_type_pkg;]';
$else
    dbms_output.put_line('$$use_mime_type was not true so did not deploy package mime_type_pkg');
$end
END;
/
