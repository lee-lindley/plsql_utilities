whenever sqlerror continue
prompt run these one at a time if you want to see the query result in sqldeveloper
drop table ztest_ptf_tbl;
whenever sqlerror exit failure
create table ztest_ptf_tbl(
    id  NUMBER
    ,"String Id"    VARCHAR2(128)
    ,bd             BINARY_DOUBLE
    ,timestamp      TIMESTAMP
    ,"My Date"      DATE
);
INSERT INTO ztest_ptf_tbl VALUES(1, 'One', 1.1, systimestamp, sysdate);
INSERT INTO ztest_ptf_tbl VALUES(2, 'Two', 2.2, systimestamp, sysdate);
INSERT INTO ztest_ptf_tbl VALUES(3, 'Three', 3.3, systimestamp, sysdate);
COMMIT;

ALTER SESSION SET NLS_DATE_FORMAT='MM/DD/YYYY';
WITH R AS (
    SELECT *
    FROM csv_to_table_pkg.split_clob_to_lines(
q'!
1,"One",1.1,01/02/2022 08.44.12.370423000 AM,01/02/2022
2,"Two",2.2,01/02/2022 08.44.12.477616000 AM,01/02/2022
3,"Three",3.3,01/02/2022 08.44.12.483012000 AM,01/02/2022
!'
    )
) SELECT *
FROM csv_to_table_pkg.ptf(p_tab => R
                            , p_columns => 'id, "String Id", bd, timestamp, "My Date"'
--"ID","String Id","BD","TIMESTAMP","My Date"
                            , p_table_name => 'ztest_ptf_tbl'
                        )
;
DROP TABLE ztest_ptf_tbl;
/*
Result exported from sqldeveloper as CSV:
"ID","String Id","BD","TIMESTAMP","My Date"
1,"One",1.1,01/02/2022 08.44.12.370423000 AM,01/02/2022
2,"Two",2.2,01/02/2022 08.44.12.477616000 AM,01/02/2022
3,"Three",3.3,01/02/2022 08.44.12.483012000 AM,01/02/2022
*/

