whenever sqlerror continue
DROP TYPE app_part_exchg_det_arr_udt FORCE;
prompt OK if drop failed for not exists
whenever sqlerror exit failure
CREATE OR REPLACE TYPE app_part_exchg_det_udt FORCE AS OBJECT(
    type        VARCHAR2(30) -- TABLE, INDEX, DROP
    ,ddl        CLOB
    ,can_fail   VARCHAR2(1)
    ,CONSTRUCTOR FUNCTION app_part_exchg_det_udt RETURN SELF AS RESULT
)
;
/
show errors
CREATE OR REPLACE TYPE BODY app_part_exchg_det_udt
IS
    CONSTRUCTOR FUNCTION app_part_exchg_det_udt
    RETURN SELF AS RESULT
    IS
    BEGIN
        RETURN;
    END app_part_exchg_det_udt;
END;
/
show errors
CREATE OR REPLACE TYPE app_part_exchg_det_arr_udt AS TABLE OF app_part_exchg_det_udt;
/
show errors
