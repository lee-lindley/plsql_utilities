set serveroutput on
set linesize 1000
set pagesize 0
DECLARE
    v_str   VARCHAR2(4000);
BEGIN
    v_str := perlish_util_udt(p_map_string => 'x.pu_udt.get($##index_val##) AS C$##index_val##'
                              , p_last => 5
                             ).join(CHR(10)||',');
    DBMS_OUTPUT.put_line(v_str);
END;
/
