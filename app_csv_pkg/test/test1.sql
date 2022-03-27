set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
spool test1.txt
WITH R AS (
    SELECT * FROM hr.departments ORDER BY department_name
) SELECT *
FROM app_csv_pkg.ptf(R
                     ,p_separator   => '|'
                     ,p_header_row  => 'Y'
                    )
;
spool off
