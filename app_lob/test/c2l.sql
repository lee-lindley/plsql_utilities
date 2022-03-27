set define off
WITH a AS (
    SELECT level AS i, TO_CHAR(level)||',"'||TO_CHAR(sysdate,'MM/DD/YYYY')||'","dummy text to pad it out"' AS r
    FROM dual
    CONNECT BY level <= 1500
)
SELECT 
    --LENGTH(
    app_lob.clobtoliterals(
            REPLACE(
                RTRIM(XMLAGG(XMLELEMENT(e, r||CHR(10)) ORDER BY i).EXTRACT('//text()').getclobval(), 'CHR(10)')
                ,'&quot;','"'
            )
    )
FROM a;
--
-- verify it breaks after a linefeed 
--
WITH a AS (
    SELECT level AS i, TO_CHAR(level)||',"'||TO_CHAR(sysdate,'MM/DD/YYYY')||'","dummy text to pad it out"' AS r
    FROM dual
    CONNECT BY level <= 1500
)
SELECT 
    --LENGTH(
    app_lob.clobtoliterals(
            REPLACE(
                RTRIM(XMLAGG(XMLELEMENT(e, r||CHR(10)) ORDER BY i).EXTRACT('//text()').getclobval(), 'CHR(10)')
                ,'&quot;','"'
            )
            ,'Y'
    )
FROM a;
