CREATE OR REPLACE PACKAGE BODY app_lob
IS
    PROCEDURE blobtofile(
         p_blob                     BLOB
        ,p_directory                VARCHAR2
        ,p_filename                 VARCHAR2
    )
    AS
        v_file              UTL_FILE.file_type;
        v_buffer            RAW(32767);
        v_amount            BINARY_INTEGER := 32767;
        v_pos               INTEGER := 1;
        v_blob_len          INTEGER;
    BEGIN
        v_blob_len := DBMS_LOB.getlength(p_blob);
        v_file := UTL_FILE.fopen(p_directory, p_filename, 'wb', 32767);
        WHILE v_pos <=  v_blob_len LOOP
            DBMS_LOB.read(p_blob, v_amount, v_pos, v_buffer);
            UTL_FILE.put_raw(v_file, v_buffer, TRUE);
            v_pos := v_pos + v_amount;
        END LOOP;
        UTL_FILE.fclose(v_file);
    EXCEPTION WHEN OTHERS THEN
        IF UTL_FILE.is_open(v_file) THEN
            UTL_FILE.fclose(v_file);
        END IF;
        RAISE;
    END blobtofile
    ;

    FUNCTION clobtoblob(
         p_clob                     CLOB
    ) RETURN BLOB
    AS
        -- these are in/out parameters in the dbms_lob procedure
        -- we do not look at them after the call, but they must be variables
        v_dest_offset   PLS_INTEGER := 1;
        v_src_offset    PLS_INTEGER := 1;
        v_lang_context  PLS_INTEGER := DBMS_LOB.default_lang_ctx;
        v_warning       PLS_INTEGER := DBMS_LOB.warn_inconvertible_char;
        v_blob          BLOB;
    BEGIN
        DBMS_LOB.createtemporary(
            lob_loc     => v_blob
            ,cache      => TRUE
        );
        DBMS_LOB.converttoblob(
            dest_lob        => v_blob
            ,src_clob       => p_clob
            ,amount         => DBMS_LOB.lobmaxsize
            ,dest_offset    => v_dest_offset
            ,src_offset     => v_src_offset
            ,blob_csid      => DBMS_LOB.default_csid
            ,lang_context   => v_lang_context
            ,warning        => v_warning
        );
        RETURN v_blob;
    END clobtoblob
    ;

    FUNCTION filetoblob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN BLOB
    AS
        v_bfile             BFILE;
        v_blob              BLOB;
    BEGIN
        DBMS_LOB.createtemporary(v_blob, FALSE);
        v_bfile := BFILENAME(p_directory, p_filename);
        DBMS_LOB.fileopen(v_bfile, DBMS_LOB.file_readonly);
        DBMS_LOB.loadfromfile(v_blob, v_bfile, DBMS_LOB.getlength(v_bfile));
        DBMS_LOB.fileclose(v_bfile);
        RETURN v_blob;
    EXCEPTION WHEN OTHERS THEN
        IF DBMS_LOB.fileisopen(v_bfile) = 1 
            THEN DBMS_LOB.fileclose(v_bfile);
        END IF;
        DBMS_LOB.freetemporary(v_blob);
        RAISE;
    END filetoblob
    ;

    FUNCTION filetoclob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN CLOB
    AS
        v_bfile             BFILE;
        v_clob              CLOB := empty_clob();
        v_clob2             CLOB;
        v_wrn               INTEGER;
        v_src_off           INTEGER := 1;
        v_dest_off          INTEGER := 1;
        v_lang_ctx          INTEGER := 0;
    BEGIN
        v_bfile := BFILENAME(p_directory, p_filename);
        DBMS_LOB.fileopen(v_bfile, DBMS_LOB.file_readonly);
        IF DBMS_LOB.getlength(v_bfile) > 0 THEN
            DBMS_LOB.createtemporary(v_clob, TRUE);
            DBMS_LOB.loadclobfromfile(v_clob, v_bfile, DBMS_LOB.getlength(v_bfile)
                ,v_dest_off
                ,v_src_off
                ,0, v_lang_ctx, v_wrn
            );
            v_clob2 := v_clob;
            DBMS_LOB.freetemporary(v_clob);
        END IF;
        DBMS_LOB.fileclose(v_bfile);
        RETURN v_clob2;
    EXCEPTION WHEN OTHERS THEN
        IF DBMS_LOB.fileisopen(v_bfile) = 1 
            THEN DBMS_LOB.fileclose(v_bfile);
        END IF;
        DBMS_LOB.freetemporary(v_clob);
        RAISE;
    END filetoclob
    ;

END app_lob;
/
show errors
-- it is invoker rights, so would not hurt anything to share it. 
--GRANT EXECUTE ON app_lob TO PUBLIC;
