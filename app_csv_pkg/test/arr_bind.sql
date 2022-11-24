declare
    v_arr_arr arr_arr_varchar2_udt := arr_arr_varchar2_udt(
        arr_varchar2_udt('abc','123','xyz')
        ,arr_varchar2_udt('def','456','mno')
        ,arr_varchar2_udt('h1','h2','h3')
    );

    v_src sys_refcursor;
    v_line  varchar2(4000);
begin
    /*
*/
    open v_src for q'!WITH FUNCTION wget(
    p_arr   ARR_VARCHAR2_UDT
    ,p_i    NUMBER
) RETURN VARCHAR2
AS
BEGIN
    RETURN p_arr(p_i);
END;
a AS (
    SELECT rownum AS rn, t.COLUMN_VALUE AS arr 
    FROM TABLE(:my_tab) t
    WHERE rownum < :my_count
), b AS (
select wget(a.arr,1) AS c1, wget(a.arr,2) AS c2, wget(a.arr,3) AS c3
FROM a
ORDER BY rn
) SELECT c1||'-'||c2||'-'||c3
FROM b!' USING v_arr_arr, v_arr_arr.COUNT
;
    LOOP
        FETCH v_src INTO v_line;
        EXIT WHEN v_src%NOTFOUND;
        dbms_output.put_line(v_line);
    END LOOP;
    CLOSE v_src;
END;

