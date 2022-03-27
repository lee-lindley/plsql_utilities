DECLARE
    v_sql   CLOB;
BEGIN
    v_sql := q'[SELECT * FROM (
        SELECT TO_CHAR(employee_id) AS "Emp ID", last_name||', '||first_name AS "Fname", hire_date AS "Date,Hire,YYYYMMDD", salary AS "Salary"
        from hr.employees
        UNION ALL
        SELECT '999' AS "Emp ID", '  Baggins, Bilbo "badboy" ' AS "Fname", TO_DATE('19991231','YYYYMMDD') AS "Date,Hire,YYYYMMDD", 123.45 AS "Salary"
        FROM dual
      ) ORDER BY LTRIM("Fname") 
]';
    app_csv_udt.write_file(
        p_dir           => 'TMP_DIR'
        ,p_file_name    => 'x.csv'
        ,p_sql          => v_sql
        ,p_num_format   => '$999,999.99'
        ,p_date_format  => 'YYYYMMDD'
    );
END;
/
set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
set long 90000
set serveroutput on
spool test5.csv
SELECT TO_CLOB(BFILENAME('TMP_DIR','x.csv')) FROM dual
;
spool off
