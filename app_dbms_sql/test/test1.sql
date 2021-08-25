set serveroutput on
spool test1.txt
declare
    v_src SYS_REFCURSOR;
    v_a app_dbms_sql.t_arr_varchar2;
    v_ctx BINARY_INTEGER;
begin
    open v_src for select * from hr.departments;
    v_ctx := app_dbms_sql.convert_cursor(v_src);
    v_a := app_dbms_sql.get_column_names(v_ctx);
    for i in 1..v_a.count
    loop
        dbms_output.put(v_a(i)||',');
    end loop;
    dbms_output.new_line;
    loop
        v_a := app_dbms_sql.get_next_column_values(v_ctx);
        exit when v_a is null;
        for i in 1..v_a.count
        loop
            dbms_output.put(v_a(i)||',');
        end loop;
        dbms_output.new_line;
    end loop;
end;
/
spool off

