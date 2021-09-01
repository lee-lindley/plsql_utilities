prompt assumes test1.sql ran and created 4 files in TMP_DIR
prompt call from sqldeveloper, double click on the BLOB placeholder in the results and choose Download.
prompt save to any directory (like c:\temp) as "x.zip".
SELECT app_zip_udt().add_files('TMP_DIR', 'a.txt, b.txt, x.txt, y.txt').get_zip() AS zip_file_blob FROM DUAL;
