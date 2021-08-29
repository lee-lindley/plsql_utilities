set serveroutput on
spool test1.txt
declare
    v_src       SYS_REFCURSOR;
    v_col_names arr_varchar2_udt;
    v_row       arr_clob_udt;
    v_app_sql   app_dbms_sql_str_udt;
begin
    open v_src for select * from hr.departments;
    v_app_sql := app_dbms_sql_str_udt(p_cursor => v_src);
    v_col_names := v_app_sql.get_column_names;
    for i in 1..v_col_names.count
    loop
        dbms_output.put(v_col_names(i)||',');
    end loop;
    dbms_output.new_line;
    loop
        v_app_sql.get_next_column_values(v_row);
        exit when v_row is null;
        for i in 1..v_row.count
        loop
            dbms_output.put(v_row(i)||',');
        end loop;
        dbms_output.new_line;
    end loop;
end;
/
spool off

