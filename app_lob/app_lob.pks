CREATE OR REPLACE PACKAGE &&compile_schema..app_lob
AUTHID CURRENT_USER
IS
-- documentation at https://github.com/lee-lindley/plsql_utilities
    FUNCTION clobtoliterals(
        p_clob                      CLOB
        ,p_split_on_lf              VARCHAR2 DEFAULT 'n' -- back up to prior LF for end of chunk
        ,p_quote_char_start         VARCHAR2 DEFAULT '`'
        ,p_quote_char_end           VARCHAR2 DEFAULT '`'
    ) RETURN CLOB
    ;
    /*
        Purpose: convert a clob into a series of concatenated quoted character literal
            values each of which are less than the 32767 limit. Allows encoding
            clob content into a SQL input file that can be executed in sqlplus
            or other command line or gui tools.
            The most common use case is to provide CLOB data for a code promotion
            file as can be used in most CI/Devops deployment tools.
            The returned value extracted from the database as text can be passed
            to any function or procedure that accepts a CLOB value or assigned
            to a CLOB variable in an anonymous block.

        Example:
            SELECT app_lob.clobtoliterals(doc_content)
            FROM my_clob_table
            WHERE id = 123;
        
        Result:
            TO_CLOB(q'`...`'
            ||TO_CLOB(q'`...`'
            ||TO_CLOB(q'`...`'
    */

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
        p_blob                      BLOB
        ,p_directory                VARCHAR2
        ,p_filename                 VARCHAR2
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
         p_clob                     CLOB
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
