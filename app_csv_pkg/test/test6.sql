--set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
set long 90000
set serveroutput on
spool test6.csv
WITH R AS (
    SELECT TO_CHAR(department_id, 09999) AS "Department ID", department_name, manager_id, location_id
    FROM hr.departments
    ORDER BY department_name
) SELECT *
FROM app_csv_pkg.ptf(
    p_tab           => R
    ,p_protect_numstr_from_excel => 'Y'
)
;
spool off
