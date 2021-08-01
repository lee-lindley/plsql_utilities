CREATE TABLE app_log_1 (
--
-- The main logging table. It does not have the app_name string in it, so a join view can make it more convenient.
-- The Procedure app_log_udt.purge_old can be run to purge older log records. 
--
-- Do not put any indexes or FK constraints on this. We want inserts to be cheap and fast!!!
-- Reading the table is a person doing research. They can afford full table scans.
--
-- We use two tables with a synonym to facilitate purging without interruption. You will never
-- use these two table names directly, but instead the synonym "APP_LOG" if you are in the same schema
-- (or if you create a public synonym), or the view APP_LOG_BASE_V which uses the local synonym.
-- The synonym switches between the tables during purge events.
--
     app_id     NUMBER(38) NOT NULL 
    ,ts         timestamp WITH LOCAL TIME ZONE
    ,msg        VARCHAR2(4000) 
);
CREATE TABLE app_log_2 (
     app_id     NUMBER(38) NOT NULL 
    ,ts         timestamp WITH LOCAL TIME ZONE
    ,msg        VARCHAR2(4000) 
);
CREATE OR REPLACE SYNONYM app_log FOR app_log_1;
-- when the synonym changes, so do the views that use it

