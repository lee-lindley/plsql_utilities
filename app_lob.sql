whenever sqlerror exit failure
--ALTER SESSION SET PLSQL_CCFLAGS='use_app_log:TRUE';
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
CREATE OR REPLACE PACKAGE BODY app_lob
IS
    PROCEDURE blob_to_file(
         p_filename                 VARCHAR2
        ,p_directory                VARCHAR2
        ,p_blob                     BLOB
$if $$use_app_log $then
        ,p_logger                   app_log_udt DEFAULT NULL -- we can use yours if you want the messages to have your applicaton id
$end
    )
    AS
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
                app_lob.blob_to_file(
                    p_blob          => l_blob
                    ,p_directory    => 'MYDIRECTORY'
                    ,p_filename     => 'thisfilename.txt'
                );
            end;
    */
        v_file              UTL_FILE.file_type;
        v_buffer            RAW(32767);
        v_amount            BINARY_INTEGER := 32767;
        v_pos               INTEGER := 1;
        v_blob_len          INTEGER;
    
$if $$use_app_log $then
        v_log               app_log_udt := NVL(p_logger,app_log_udt('APP_LOB'));
$end
    BEGIN
        v_blob_len := DBMS_LOB.getlength(p_blob);
        v_file := UTL_FILE.fopen(p_directory, p_filename, 'wb', 32767);
        WHILE v_pos <=  v_blob_len LOOP
            DBMS_LOB.read(p_blob, v_amount, v_pos, v_buffer);
            UTL_FILE.put_raw(v_file, v_buffer, TRUE);
            v_pos := v_pos + v_amount;
        END LOOP;
        UTL_FILE.fclose(v_file);
$if $$use_app_log $then
        v_log.log_p('wrote '||TO_CHAR(v_pos)||' bytes to file '||p_filename||' in directory '||p_directory);
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
            IF UTL_FILE.is_open(v_file) THEN
                UTL_FILE.fclose(v_file);
            END IF;
            RAISE;
    END blob_to_file
    ;
    FUNCTION clob_to_blob(
         p_data                     CLOB
$if $$use_app_log $then
         ,p_logger                  app_log_udt DEFAULT NULL
$end
    ) RETURN BLOB
    AS
    /*
        Purpose: provide facility for converting a CLOB to a BLOB for storing in a column
        
        Example:
            declare
                l_clob CLOB := 'this is a test';
            begin
                INSERT INTO xyz(blob_col) VALUES(app_lob.clob_to_blob(l_clob));
            end;
    */
        v_blob          BLOB;
        -- these are in/out parameters in the dbms_lob procedure
        -- we do not look at them after the call, but they must be variables
        v_dest_offset   PLS_INTEGER := 1;
        v_src_offset    PLS_INTEGER := 1;
        v_lang_context  PLS_INTEGER := DBMS_LOB.default_lang_ctx;
        v_warning       PLS_INTEGER := DBMS_LOB.warn_inconvertible_char;
    BEGIN
        DBMS_LOB.createtemporary(
            lob_loc     => v_blob
            ,cache      => TRUE
        );
        DBMS_LOB.converttoblob(
            dest_lob        => v_blob
            ,src_clob       => p_data
            ,amount         => DBMS_LOB.lobmaxsize
            ,dest_offset    => v_dest_offset
            ,src_offset     => v_src_offset
            ,blob_csid      => DBMS_LOB.default_csid
            ,lang_context   => v_lang_context
            ,warning        => v_warning
        );
        RETURN v_blob;
    EXCEPTION WHEN OTHERS THEN
$if $$use_app_log $then
        DECLARE
            v_log app_log_udt := NVL(p_logger,app_log_udt('APP_LOB'));
        BEGIN
            v_log.log_p('sqlerrm    : '||SQLERRM);
            v_log.log_p('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            v_log.log_p('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
        END;
$else
            DBMS_OUTPUT.put_line('sqlerrm    : '||SQLERRM);
            DBMS_OUTPUT.put_line('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            DBMS_OUTPUT.put_line('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
$end
            RAISE;
    END clob_to_blob
    ;

    FUNCTION file_to_blob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
$if $$use_app_log $then
        ,p_logger                   app_log_udt DEFAULT NULL -- we can use yours if you want the messages to have your applicaton id
$end
    ) RETURN BLOB
    AS
    /*
        Purpose: provide a facility for reading a blob from a file 
        
        Example:
            declare
                l_blob BLOB;
            begin
                l_blob := app_lob.file_to_blob(
                    p_filename      => 'myfile.txt'
                    ,p_directory    => 'MYDIR'
                );
            end;
    */
    
        v_bfile             BFILE;
        v_blob              BLOB;
$if $$use_app_log $then
        v_log               app_log_udt := NVL(p_logger, app_log_udt('GZPUTIL_FILE_TO_BLOB'));
$end
    BEGIN
        DBMS_LOB.createtemporary(v_blob, FALSE);
        --v_log.log_p('wrote '||TO_CHAR(v_pos)||' bytes to file '||p_filename||' in directory '||p_directory);
        v_bfile := BFILENAME(p_directory, p_filename);
        DBMS_LOB.fileopen(v_bfile, DBMS_LOB.file_readonly);
        DBMS_LOB.loadfromfile(v_blob, v_bfile, DBMS_LOB.getlength(v_bfile));
        DBMS_LOB.fileclose(v_bfile);
        RETURN v_blob;
    
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
            IF DBMS_LOB.fileisopen(v_bfile) = 1 
                THEN DBMS_LOB.fileclose(v_bfile);
            END IF;
            DBMS_LOB.freetemporary(v_blob);
            RAISE;
    END file_to_blob
    ;
END app_lob;
/
show errors
-- it is invoker rights, so would not hurt anything to share it. 
--GRANT EXECUTE ON app_lob TO PUBLIC;
