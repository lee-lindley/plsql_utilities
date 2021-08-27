set serveroutput on
DECLARE
    l_z app_zip_udt := app_zip_udt;
    l_zip_blob  BLOB;
    l_file_list as_zip.file_list;
BEGIN
    l_z.add_clob('some text in a clob', 'folder_x/y.txt');
    dbms_lob.clob2file('This is from clob2file'||CHR(10), 'TMP_DIR', 'x.txt');
    dbms_lob.clob2file('This is also from clob2file'||CHR(10), 'TMP_DIR', 'y.txt');
    dbms_lob.clob2file('This is from clob2file'||CHR(10), 'TMP_DIR', 'a.txt');
    dbms_lob.clob2file('This is also from clob2file'||CHR(10), 'TMP_DIR', 'b.txt');
    l_z.add_files('TMP_DIR', 'x.txt, y.txt');
    l_z.add_files('TMP_DIR/a.txt, TMP_DIR/b.txt');
    l_zip_blob := l_z.get_zip;
    l_file_list := as_zip.get_file_list(l_zip_blob);
    FOR i IN 1..l_file_list.COUNT
    LOOP
        DBMS_OUTPUT.put_line('i='||TO_CHAR(i)||' filename='||l_file_list(i));
    END LOOP;
    app_lob.blobtofile(l_zip_blob, 'TMP_DIR', 'x.zip');
    DBMS_OUTPUT.put_line(q'!file x.zip written to TMP_DIR. In sqldeveloper run the following select. 
In the results double click on the "BLOB" placeholder. Click on the pencil icon. Choose "Download".
Save as "x.zip" somewhere.

SELECT app_lob.filetoblob('TMP_DIR','x.zip') AS zipfile FROM DUAL;!');
END;
/
