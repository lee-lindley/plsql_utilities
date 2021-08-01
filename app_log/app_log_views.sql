-- readers other than the schema owner can have the
-- private synonym resolved for them. Could use a public synonym
-- instead. See purge_old procedure if you change that and
-- the schema owner will need a way to set the public synonym.
CREATE OR REPLACE VIEW app_log_base_v(app_id, ts, msg)  AS
SELECT app_id, ts, msg
FROM app_log
;
--
-- A view to allow querying via appname.
--
CREATE OR REPLACE VIEW app_log_v(app_name, app_id, ts, msg)  AS
SELECT i.app_name, a.app_id, a.ts, a.msg
FROM app_log_app i
INNER JOIN app_log_base_v a
    ON a.app_id = i.app_id
;
--
-- Tail the last 20 records of the log
--
CREATE OR REPLACE VIEW app_log_tail_v(time_stamp, elapsed, logmsg, app_name) AS
    WITH a AS (
        SELECT app_id, ts, msg 
        FROM app_log_base_v
        ORDER BY ts DESC FETCH FIRST 20 ROWS ONLY
    ), b AS (
        SELECT app_name, ts, ts - (LAG(ts) OVER (ORDER BY ts)) AS ts_diff, msg
        FROM a
        INNER JOIN app_log_app ap 
            ON ap.app_id = a.app_id
    ) SELECT 
         TO_CHAR(ts, 'HH24:MI.SS.FF2')  AS time_stamp
        ,TO_CHAR(EXTRACT(MINUTE FROM ts_diff)*60 + EXTRACT(SECOND FROM ts_diff), '999.9999') 
                                        AS elapsed
        ,SUBSTR(msg,1,75)               AS logmsg
        ,app_name                       AS appname
    FROM b
    ORDER BY b.ts
;
