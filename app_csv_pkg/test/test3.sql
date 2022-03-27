DECLARE
    v_src   SYS_REFCURSOR;
BEGIN
    OPEN v_src FOR WITH R AS (
        SELECT TO_CHAR(employee_id) AS "Emp ID", last_name||', '||first_name AS "Fname", hire_date AS "Date,Hire,YYYYMMDD", salary AS "Salary"
        from hr.employees
        UNION ALL
        SELECT '999' AS "Emp ID", '  Baggins, Bilbo "badboy" ' AS "Fname", TO_DATE('19991231','YYYYMMDD') AS "Date,Hire,YYYYMMDD", 123.45 AS "Salary"
        FROM dual
      ) 
        SELECT *
        FROM app_csv_pkg.ptf(R ORDER BY "Fname"
                                ,p_num_format   => '$999,999.99'
                                ,p_date_format  => 'YYYYMMDD'
                            )

    ;
    app_csv_pkg.write_file(p_dir => 'TMP_DIR', p_file_name => 'x.csv', p_src => v_src);
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
spool test3.csv
SELECT TO_CLOB(BFILENAME('TMP_DIR','x.csv')) FROM dual
;
spool off
