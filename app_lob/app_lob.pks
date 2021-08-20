CREATE OR REPLACE PACKAGE app_lob
AUTHID CURRENT_USER
IS
/*
    This is all code you can find on the web or even in the Oracle documentation.
    Seems like Oracle should have put these in DBMS_LOB.
    I will not be so silly as to copyright or license it.
*/


    /*
        Purpose: provide a facility for writing a blob to a file 
        
        Example:
            declare
                l_blob BLOB;
            begin
                -- get lob locator
                SELECT gjrjflu_file INTO l_blob
                FROM gjrjflu
                WHERE gjrflu_job = :this_job_name AND gjrjflu_one_up_no = :this_one_up_no
                ;
                app_lob.blobtofile(
                    p_blob          => l_blob
                    ,p_directory    => 'MYDIRECTORY'
                    ,p_filename     => 'thisfilename.txt'
                );
            end;
    */
    PROCEDURE blobtofile(
        p_filename                 VARCHAR2
        ,p_directory                VARCHAR2
        ,p_blob                     BLOB
    );

    /*
        Purpose: provide facility for converting a CLOB to a BLOB for storing in a column
        
        Example:
            declare
                l_clob CLOB := 'this is a test';
            begin
                INSERT INTO xyz(blob_col) VALUES(app_lob.clobtoblob(l_clob));
            end;
    */
    FUNCTION clobtoblob(
         p_data                     CLOB
    ) RETURN BLOB
    ;


    /*
        Purpose: provide a facility for reading a blob from a file 
        
        Example:
            declare
                l_blob BLOB;
            begin
                l_blob := app_lob.filetoblob(
                    p_filename      => 'myfile.txt'
                    ,p_directory    => 'MYDIR'
                );
            end;
    */
    FUNCTION filetoblob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN BLOB
    ;


    /*
        Purpose: provide a facility for reading a blob from a file 

        TO_CLOB(BFILENAME(dir,file_name)) works in a sql select, but not in pl/sql directly.
        
        Example:
            declare
                l_clob CLOB;
            begin
                l_clob := app_lob.filetoclob(
                    p_filename      => 'myfile.txt'
                    ,p_directory    => 'MYDIR'
                );
            end;
    */
    FUNCTION filetoclob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN CLOB
    ;

END app_lob;
/
show errors
