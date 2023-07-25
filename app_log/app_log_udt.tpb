CREATE OR REPLACE TYPE BODY app_log_udt AS

    CONSTRUCTOR FUNCTION app_log_udt(
        p_app_name  VARCHAR2
    )
    RETURN SELF AS RESULT
    IS
    BEGIN
        SELF.app_log_udt_constructor(p_app_name);
        RETURN;
    END; -- end constructor app_log_udt

    FINAL MEMBER PROCEDURE app_log_udt_constructor(
        SELF IN OUT app_log_udt
        ,p_app_name VARCHAR2
    )
    IS
        -- we create the log messages independent from the main body who may commit or rollback separately
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_not_found     VARCHAR2(1) := 'N';
    BEGIN
        app_name := UPPER(p_app_name);
        FOR i IN 1..3 -- could have simultaneous attempts to create new app_id
        LOOP
            BEGIN
                SELECT app_id INTO SELF.app_id 
                FROM app_log_app 
                WHERE app_name = SELF.app_name
                ;
            EXCEPTION WHEN NO_DATA_FOUND
            THEN 
                v_not_found := 'Y';
            END;
            IF v_not_found = 'Y' THEN
                BEGIN
                    SELF.app_id := app_log_app_seq.NEXTVAL;
                    INSERT INTO app_log_app(app_id, app_name) VALUES (SELF.app_id, SELF.app_name);
                    COMMIT;
                    EXIT;
                EXCEPTION WHEN OTHERS THEN -- unique key constraint from simultaneous attempts to create new one
                    SELF.app_id := NULL;
                    v_not_found := 'N'; -- reset for next loop iteration
                END;
            ELSE
                EXIT;
            END IF;
        END LOOP;
        IF SELF.app_id IS NULL THEN
            raise_application_error(-20111,'failed to get unique key for app_name in app_log_udt constructor');
        END IF;
    END app_log_udt_constructor; 

    FINAL MEMBER PROCEDURE log(p_msg VARCHAR2)
    IS
        -- we create the log messages independent from the main body who may commit or rollback separately
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_i BINARY_INTEGER := 1;
    BEGIN
        WHILE v_i <= LENGTH(p_msg)
        LOOP
            INSERT INTO app_log(app_id, ts, msg) VALUES (SELF.app_id, CURRENT_TIMESTAMP, SUBSTR(p_msg,v_i,4000));
            v_i := v_i + 4000;
        END LOOP;
        COMMIT;
    END log
    ; 

    FINAL MEMBER PROCEDURE log_p(p_msg VARCHAR2)
    IS
    -- log and print to console
    BEGIN
        -- note that we do not truncate the message for dbms_output
        DBMS_OUTPUT.PUT_LINE(app_name||' logmsg: '||p_msg);
        SELF.log(p_msg); 
    END log_p
    ; 


    FINAL STATIC PROCEDURE log(p_app_name VARCHAR2, p_msg VARCHAR2)
    IS
        l app_log_udt := app_log_udt(p_app_name);
    BEGIN
        l.log(p_msg);
    END log
    ;
    FINAL STATIC PROCEDURE log_p(p_app_name VARCHAR2, p_msg VARCHAR2)
    IS
        l app_log_udt := app_log_udt(p_app_name);
    BEGIN
        l.log_p(p_msg);
    END log_p
    ;

    FINAL STATIC PROCEDURE purge_old(p_days NUMBER := 90)
    IS
        v_log_obj       app_log_udt := app_log_udt('app_log');
        v_which_table   VARCHAR2(128); -- 30 is true max, but many dba tables allow 128
        v_dest_table    VARCHAR2(128);
        v_rows          BINARY_INTEGER;
    BEGIN
        v_log_obj.log_p('Procedure purge_old called with arg p_days='||TO_CHAR(p_days));
    
        --
        -- Figure out which base table is currently being written to
        --
        SELECT table_name INTO v_which_table
        FROM user_synonyms
        WHERE synonym_name = 'APP_LOG'
        ;
        --
        -- The one we are going to truncate and write to next is the other one
        --
        v_dest_table := CASE WHEN v_which_table = 'APP_LOG_1' 
                             THEN 'APP_LOG_2' 
                             ELSE 'APP_LOG_1'
                        END;
        EXECUTE IMMEDIATE 'TRUNCATE TABLE '||v_dest_table||' DROP ALL STORAGE';
        v_log_obj.log_p('truncated table '||v_dest_table);
        --
        -- Here is the magic. We swap the synonym. That means any
        -- new writes via the app_log_udt object will insert into the 
        -- new destination table (which is currently empty) and no longer write to the
        -- old table. This takes care of any writes that are going on while we are performing
        -- the rest of this task and prevents any blocking that might otherwise happen
        -- from our activity. The views will also resolve through the local synonym, so
        -- there is a brief time where the existing log records have disappeared until
        -- we commit the insert.
        --
        -- I was happy with an implementation of this using a single table and a dummy
        -- partitioned table with exchange partition, but it was pointed out that not
        -- everyone pays for the partition license.
        --
        EXECUTE IMMEDIATE 'CREATE OR REPLACE SYNONYM app_log FOR '||v_dest_table;
        --
        -- copy from the prior table any records less than X days old.
        -- The old table stays there and still has the "about to be forgotten" records
        -- until the next time we run
        --
        EXECUTE IMMEDIATE 'INSERT /*+ append */ INTO '||v_dest_table||'
            SELECT *
            FROM '||v_which_table||'
            WHERE ts > TRUNC(SYSDATE) - '||TO_CHAR(p_days)
        ;
        v_rows := SQL%rowcount;
        COMMIT;
        -- must commit before logging because logging writes to same table we just direct path wrote!!!
        v_log_obj.log_p('Copied back from '||v_which_table||' to '||v_dest_table||' '||TO_CHAR(v_rows)||' records less than '||TO_CHAR(p_days)||' days old');
    END purge_old;
END;
/
show errors
