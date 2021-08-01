--
-- It would be best if anyone trying to add/update/delete values from the table used the package
-- procedures in app_parameter, but if one insists on doing direct DML, we have some triggers
-- to try to keep you out of trouble.
-- 
CREATE OR REPLACE TRIGGER app_parameters_ins
    BEFORE INSERT ON app_parameters
    FOR EACH ROW
        WHEN (NEW.created_by IS NULL OR NEW.created_dt IS NULL)
        BEGIN
            :NEW.created_by := SYS_CONTEXT('USERENV','SESSION_USER');
            :NEW.created_dt := SYSDATE;
        END;
/
show errors
CREATE OR REPLACE TRIGGER app_parameters_upd
    BEFORE UPDATE OR DELETE ON app_parameters
    FOR EACH ROW
        WHEN (NEW.end_date IS NULL OR NEW.end_dated_by IS NULL)
        BEGIN
            IF :NEW.end_date IS NULL THEN
                RAISE_APPLICATION_ERROR(-20001, 'Must end_date a record to update app_parameters table. Should not be deleting. Use app_parameter procedures instead. param_name='||:NEW.param_name);
            END IF;
            IF :NEW.end_dated_by IS NULL THEN
                :NEW.end_dated_by := SYS_CONTEXT('USERENV','SESSION_USER');
            END IF;
        END;
/
show errors
