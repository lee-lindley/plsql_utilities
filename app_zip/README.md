# app_zip

- add BLOB to zip
- add CLOB to zip
- add 1 or more files to zip from Database Directory Object(s)
- get finished zip BLOB

An object type wrapper for [as_zip](#../as_zip), it adds methods for adding clobs and for
adding multiple files at once from a comma separated list string. The functionality
is exclusively for creating the zip archive BLOB. If you want to list the file content
or grab a file from a zip, use *as_zip* directly.

The method interface is:
```sql
    ,CONSTRUCTOR FUNCTION app_zip_udt RETURN SELF AS RESULT
    -- once you call get_zip, the object blob is no longer useful. You cannot add to it
    -- nor can you call get_zip again.
    ,MEMBER FUNCTION get_zip RETURN BLOB
    ,MEMBER PROCEDURE add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    --
    ,MEMBER PROCEDURE add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    --
    -- I never should have differentiated between add_file and add_files plural.
    -- You can use either name. If the file name string contains a comma, it will split it as
    -- multiple files.
    --
    ,MEMBER PROCEDURE add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- comma separated list of file names (or not)
    ,MEMBER PROCEDURE add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    --
    -- names should have dir as first component before slash
    --
    ,MEMBER PROCEDURE add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    -- these work identically to add_files
    ,MEMBER PROCEDURE add_file(
        p_name          VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    )
    -- callable in a chain
    ,MEMBER FUNCTION add_file(
        p_name          VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
```

Example:
```sql
    DECLARE
        l_zip   BLOB;
        l_z     app_zip_udt;
    BEGIN
        l_z := app_zip_udt;
        l_z.add_clob('some text in a clob', 'folder_x/y.txt');
        l_z.add_files('TMP_DIR', 'x.txt,y.xlsx,z.csv');
        l_z.add_files('TMP_DIR/a.txt, TMP_DIR/b.xlsx, TMP_DIR/c.csv');
        l_z.add_files('TMPDIR/z.pdf');
        l_z.add_file('TMPDIR/sample.pdf');
        l_zip := l_z.get_zip;
        INSERT INTO mytable(file_name, blob_content) VALUES ('my_zip_file.zip', l_zip);
        COMMIT;
    END;
```

Examples with method chaining:

```sql
    -- chaining function calls without declaring a variable
    INSERT INTO mytable(file_name, blob_content)
        VALUES('my_zip_file.zip'
            ,app_zip_udt().add_files('TMP_DIR/a.txt, TMP_DIR/b.xlsx, TMP_DIR/c.csv').get_zip()
        )
    COMMIT;

    SELECT app_zip_udt().add_file(m.blob_content, m.file_name).get_zip() AS zip_file_blob
    FROM mytable m
    WHERE m.file_name = 'my_big_file.csv'
    ;

    SELECT app_zip_udt().add_file('TMP_DIR', 'some_big_file.csv').get_zip() AS zip_file_blob FROM DUAL;
```

The *test* subdirectory of the *app_zip* folder may be helpful for seeing it in action.

