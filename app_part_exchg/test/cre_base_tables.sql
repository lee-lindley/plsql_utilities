prompt OK for drops to fail for table not exists
whenever sqlerror continue
DROP TABLE testpe_master_p;
DROP TABLE testpe_master_np;
DROP TABLE t12345678901234567890123456789;
DROP TABLE testpe_master_plain;
--
-- create partitioned table for partition exchange dummy testing
whenever sqlerror exit failure
CREATE TABLE testpe_master_p(
    ts      TIMESTAMP WITH LOCAL TIME ZONE
    ,app_id NUMBER NOT NULL
    ,msg    VARCHAR2(4000) NOT NULL
    --,CONSTRAINT testpe_master_p_pk PRIMARY KEY(pk)
) PARTITION BY RANGE(ts)
(
    --PARTITION pearliest VALUES LESS THAN (CAST(TO_DATE('20220101', 'YYYYMMDD') AS TIMESTAMP WITH LOCAL TIME ZONE))
    PARTITION pearliest VALUES LESS THAN (TIMESTAMP'2022-01-01 00:00:00 +00:00') 
    ,PARTITION p202201 VALUES LESS THAN (TIMESTAMP'2022-02-01 00:00:00 +00:00')
    ,PARTITION p202202 VALUES LESS THAN (TIMESTAMP'2022-03-01 00:00:00 +00:00')
    ,PARTITION p202203 VALUES LESS THAN (TIMESTAMP'2022-04-01 00:00:00 +00:00')
    ,PARTITION pmax VALUES LESS THAN (MAXVALUE)
)
;
ALTER TABLE testpe_master_p ADD CONSTRAINT testpe_master_p_pk PRIMARY KEY(ts) USING INDEX LOCAL ENABLE;

CREATE INDEX testpe_master_p_i1 ON testpe_master_p(app_id)  LOCAL;
-- create non-partitioned table for partition exchange dummy testing

CREATE TABLE testpe_master_np(
    ts      TIMESTAMP WITH LOCAL TIME ZONE
    ,app_id NUMBER NOT NULL
    ,msg    VARCHAR2(4000) NOT NULL
    ,pk     NUMBER 
    ,CONSTRAINT testpe_master_np_pk PRIMARY KEY(pk)
);
CREATE INDEX testpe_master_np_i1 ON testpe_master_np(app_id);

CREATE TABLE t12345678901234567890123456789(
    app_id  NUMBER NOT NULL
    ,app_id2 NUMBER NOT NULL
    ,msg    VARCHAR2(4000) 
);
CREATE UNIQUE INDEX t12345678901234567890123456_i1 ON t12345678901234567890123456789(app_id, app_id2);

CREATE TABLE testpe_master_plain(
    app_id NUMBER
    ,msg VARCHAR2(4000)
);

