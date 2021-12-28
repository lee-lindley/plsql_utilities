CREATE OR REPLACE PACKAGE csv_to_table_pkg 
AUTHID CURRENT_USER
AS
    FUNCTION t(
        p_tab           TABLE
        ,p_table_name   VARCHAR2
        ,p_columns      VARCHAR2 -- csv list
        ,p_clob         CLOB
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
    ) RETURN TABLE
    PIPELINED ROW POLYMORPHIC USING csv_to_table_pkg
    ;

    FUNCTION describe(
        p_tab IN OUT    DBMS_TF.TABLE_T
        ,p_table_name   VARCHAR2
        ,p_columns      VARCHAR2 -- csv list
        ,p_clob         CLOB
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
    ) RETURN DBMS_TF.DESCRIBE_T
    ;
    PROCEDURE fetch_rows(
         p_table_name   VARCHAR2
        ,p_columns      VARCHAR2 -- csv list
        ,p_clob         CLOB
        ,p_date_fmt     VARCHAR2 DEFAULT NULL -- uses nls_date_format if null
    )
    ;
END csv_to_table_pkg;
/
show errors
