declare
    v_arr_arr arr_arr_varchar2_udt := app_csv_pkg.split_clob_to_fields(q'{abc,123,xyz
def,456,mno
h1,h2,h3}'
    );
    v_src sys_refcursor;
    v_line  varchar2(4000);
begin
    /*
*/
    open v_src for q'!WITH a AS (
    SELECT rownum AS rn, perlish_util_udt(t.COLUMN_VALUE) AS arr 
    FROM TABLE(:my_tab) t
    WHERE rownum < :my_count
), b AS (
select t.arr.get(1) AS c1, t.arr.get(2) AS c2, t.arr.get(3) AS c3
FROM a t
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

