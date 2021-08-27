CREATE OR REPLACE TYPE app_zip_udt AUTHID CURRENT_USER AS OBJECT (
    /*
        DECLARE
            l_zip   BLOB;
            l_z     app_zip_udt;
        BEGIN
            l_z := app_zip_udt;
            l_z.add_clob('some text in a clob', 'folder_x/y.txt');
            l_z.add_files('TMP_DIR', 'x.txt,y.xlsx,z.csv');
            l_z.add_files('TMP_DIR/a.txt, TMP_DIR/b.xlsx, TMP_DIR/c.csv');
            l_zip := l_z.get_zip;
            INSERT INTO mytable(file_name, blob_content) VALUES ('my_zip_file.zip', l_zip);
            COMMIT;
        END;

        -- chaining function calls without declaring a variable
        INSERT INTO mytable(file_name, blob_content)
            VALUES('my_zip_file.zip'
                ,app_zip_udt().add_files('TMP_DIR/a.txt, TMP_DIR/b.xlsx, TMP_DIR/c.csv').get_zip()
            )
        COMMIT;

        SELECT app_zip_udt().add_file(m.blob_content, m.file_name).get_zip() AS zip_file_blob
        FROM mytable
        WHERE file_name = 'my_big_file.csv'
        ;

        SELECT app_zip_udt().add_file('TMP_DIR', 'some_big_file.csv').get_zip() AS zip_file_blob FROM DUAL;

    */

    z   BLOB -- don't touch this. It is not useful untill get_zip finalizes it. '
    
    ,CONSTRUCTOR FUNCTION app_zip_udt RETURN SELF AS RESULT
    -- once you call get_zip, the object blob is no longer useful. You cannot add to it
    -- nor can you call get_zip again.
    ,MEMBER FUNCTION get_zip RETURN BLOB
    ,MEMBER PROCEDURE add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    ,MEMBER PROCEDURE add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    ,MEMBER PROCEDURE add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- comma separated list of file names
    ,MEMBER PROCEDURE add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- names should have dir as first component before slash
    ,MEMBER PROCEDURE add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    ,MEMBER FUNCTION add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
);
/
show errors
