CREATE OR REPLACE TYPE app_part_exchg_udt AS OBJECT (
    -- does not work with referential constraints for now
    table_name      VARCHAR2(30)
    ,swap_name      VARCHAR2(30)
    ,schema_name    VARCHAR2(30)
    ,partitioned    VARCHAR2(3)
    ,ddls           app_part_exchg_det_arr_udt
    ,CONSTRUCTOR FUNCTION app_part_exchg_udt(
        p_table_name    VARCHAR2
        ,p_schema_name  VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
    ) RETURN SELF AS RESULT
    ,MEMBER PROCEDURE print_ddl
)
;
/
show errors
