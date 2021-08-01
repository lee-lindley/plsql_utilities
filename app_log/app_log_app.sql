CREATE TABLE app_log_app (
--
-- table will contain a record for every "application" string that is used to do logging.
-- Whenever a new application string is used, a new record will be inserted into the table by the object constructor.
--
     app_id     NUMBER(38) 
    ,app_name   VARCHAR2(30) NOT NULL
    ,CONSTRAINT app_log_app_pk PRIMARY KEY(app_id)    --ensures not null
    -- could have simultaneous constructors firing and crossing the streams.
    -- First one will win and second will raise exception. probably never happen in my lifetime.
    ,CONSTRAINT app_log_app_fk1 UNIQUE(app_name)      
);
-- no reason for large jumps. Infrequently used sequence, thus nocache.
CREATE SEQUENCE app_log_app_seq NOCACHE; 
