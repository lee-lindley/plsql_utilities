    SELECT app_lob.clobtoliterals(
                app_csv_pkg.get_clob(
                    p_sql => q'!
                        WITH a AS (
                            SELECT 
                                level AS id, CAST(TRUNC(SYSDATE) AS DATE) AS "Create Date", 'dummy text to pad it out' AS val
                            FROM dual
                            CONNECT BY level <= 1500
                        ) SELECT *
                        FROM a
                        ORDER BY id
                    !'
                )
                ,'Y'
           )
    FROM dual;

