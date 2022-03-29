# app_lob

Package provides utility methods for CLOB/BLOB types. Most of them should be in *DBMS_LOB* in my opinion.

- Function that splits a CLOB into a set of concatenated quoted literals for including in code.
- Procedures that write BLOB/CLOB to a file in a database directory object
- Functions that return a BLOB/CLOB from a database directory file
- Function that converts a CLOB to a BLOB

## Manual Page

- clobtoliterals
    ```sql
    FUNCTION clobtoliterals(
        p_clob                      CLOB
        ,p_split_on_lf              VARCHAR2 DEFAULT 'n' -- back up to prior LF for end of chunk
    ) RETURN CLOB;
    ```
    - *clobtoliterals* may be useful when you need to build a clob larger than 32767 bytes within a deployment file such as can be loaded via *sqlplus*. This is for scenarios where you cannot use traditional methods for loading the clob to the database. My use case for this is CI/Devops deployment automation that only supports SQL files run through *sqlplus*.

- blobtofile
    ```sql
    PROCEDURE blobtofile(
        p_blob                      BLOB
        ,p_directory                VARCHAR2
        ,p_filename                 VARCHAR2
    );
    ```
- clobtoblob
    ```sql
    FUNCTION clobtoblob(
         p_clob                     CLOB
    ) RETURN BLOB;
    ```
- filetoblob
    ```sql
    FUNCTION filetoblob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN BLOB;
    ```
- filetoclob
    ```sql
    -- TO_CLOB(BFILENAME(dir,file_name)) works in a sql statement, but not in pl/sql directly as of 12.2.
    FUNCTION filetoclob(
        p_directory                 VARCHAR2
        ,p_filename                 VARCHAR2
    ) RETURN CLOB;
    ```

Example 1:
```sql
    SELECT app_lob.filetoblob('TMP_DIR', 'some_file_i_wrote.zip') AS zip_file FROM dual;
```
Then from sqldeveloper or toad you can save the resulting BLOB to a file on your client machine.

Example 2:
```sql
            SELECT app_lob.clobtoliterals(doc_content)
            FROM my_clob_table
            WHERE id = 123;
```
        Result:
            TO_CLOB(q'{...}'
            ||TO_CLOB(q'{...}'
            ||TO_CLOB(q'{...}'

