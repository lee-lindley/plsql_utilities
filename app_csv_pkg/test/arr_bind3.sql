set pagesize 0
set trimspool on
set linesize 100
column c1 format a24
column c2 format a24
column c3 format a24
var curs REFCURSOR
declare
    v_arr_arr arr_arr_varchar2_udt := app_csv_pkg.split_clob_to_fields(q'{abc,123,xyz
def,456,mno
h1,h2,h3}'
    );
begin
    :curs := app_csv_pkg.get_cursor_from_collections(
        p_arr_arr   => v_arr_arr
        ,p_trim_rows => 1
    );
END;
/
print curs

