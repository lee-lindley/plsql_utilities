CREATE OR REPLACE FUNCTION app_csv_test2 RETURN CLOB
AS
    v_clob  CLOB;
BEGIN
    BEGIN
        v_clob := app_csv_pkg.get_clob(
            p_protect_numstr_from_excel => 'Y'
            ,p_sql => q'!
SELECT department_id, department_name, manager_id, TO_CHAR(location_id,'0999999') AS location_id
FROM hr.departments 
ORDER BY department_name!'
        );
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.put_line(sqlerrm);
        RAISE;
    END;
    RETURN v_clob;
END;
/
show errors
set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
set long 90000
set serveroutput on
spool test2.csv
SELECT app_csv_test2 FROM dual
;
spool off
DROP FUNCTION app_csv_test2;
