CREATE OR REPLACE TYPE BODY app_zip_udt AS
    CONSTRUCTOR FUNCTION app_zip_udt RETURN SELF AS RESULT
    IS
    BEGIN
        RETURN;
    END;

    MEMBER FUNCTION get_zip RETURN BLOB
    IS
        v_blob  BLOB := z;
    BEGIN
        IF v_blob IS NOT NULL THEN
            as_zip.finish_zip(v_blob);
        END IF;
        RETURN v_blob;
    END;

    MEMBER PROCEDURE add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) IS
    BEGIN
        as_zip.add1file(z, p_name, p_blob, p_date);
    END;
    MEMBER FUNCTION add_blob(
        p_blob      BLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    IS
        l_self  app_zip_udt := SELF;
    BEGIN
        l_self.add_blob(p_blob, p_name, p_date);
        RETURN l_self;
    END;

    MEMBER PROCEDURE add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) IS
    BEGIN
        as_zip.add1file(z, p_name, app_lob.clobtoblob(p_clob), p_date);
    END;
    MEMBER FUNCTION add_clob(
        p_clob      CLOB
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    IS
        l_self  app_zip_udt := SELF;
    BEGIN
        l_self.add_clob(p_clob, p_name, p_date);
        RETURN l_self;
    END;

    MEMBER PROCEDURE add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) IS
    BEGIN
        IF instr(p_name,',') = 0 THEN
            add_blob(app_lob.filetoblob(p_dir, p_name) ,p_name, p_date);
        ELSE
            add_files(p_dir ,p_name, p_date);
        END IF;
    END;
    MEMBER FUNCTION add_file(
        p_dir       VARCHAR2
        ,p_name     VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    IS
        l_self  app_zip_udt := SELF;
    BEGIN
        l_self.add_file(p_dir, p_name, p_date);
        RETURN l_self;
    END;

    MEMBER PROCEDURE add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) IS
        v_arr           &&d_arr_varchar2_udt.;
    BEGIN
        v_arr := perlish_util_udt.split_csv(p_name_list);
        FOR i IN 1..v_arr.COUNT
        LOOP
            add_blob(app_lob.filetoblob(p_dir, v_arr(i)) ,v_arr(i), p_date);
        END LOOP;
    END;
    MEMBER FUNCTION add_files(
        p_dir           VARCHAR2
        ,p_name_list    VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    IS
        l_self  app_zip_udt := SELF;
    BEGIN
        l_self.add_files(p_dir, p_name_list, p_date);
        RETURN l_self;
    END;

    MEMBER PROCEDURE add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) IS
        v_arr           &&d_arr_varchar2_udt.;
        v_dir           VARCHAR2(4000);
        v_name          VARCHAR2(4000);
    BEGIN
        v_arr := perlish_util_udt.split_csv(p_name_list);
        FOR i IN 1..v_arr.COUNT
        LOOP
            v_dir := REGEXP_SUBSTR(v_arr(i), '^[^/]+');
            v_name := REGEXP_SUBSTR(v_arr(i), '^[^/]+/(.+)$', 1, 1, NULL, 1);
            IF v_dir IS NULL OR v_name IS NULL THEN
                raise_application_error(-20807, 'p_name_list element '||TO_CHAR(i)||' value("'||v_arr(i)||'") did not contain dir/name string');
            END IF;
            add_blob(app_lob.filetoblob(v_dir, v_name) ,v_name, p_date);
        END LOOP;
    END;
    MEMBER FUNCTION add_files(
        p_name_list     VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    IS
        l_self  app_zip_udt := SELF;
    BEGIN
        l_self.add_files(p_name_list, p_date);
        RETURN l_self;
    END;

    -- never should have differentiated between add_file and add_files
    MEMBER PROCEDURE add_file(
        p_name      VARCHAR2
        ,p_date     DATE DEFAULT SYSDATE
    ) IS
    BEGIN
        add_files(p_name, p_date);
    END;
    MEMBER FUNCTION add_file(
        p_name          VARCHAR2
        ,p_date         DATE DEFAULT SYSDATE
    ) RETURN app_zip_udt
    IS
        l_self  app_zip_udt := SELF;
    BEGIN
        l_self.add_files(p_name, p_date);
        RETURN l_self;
    END;

END;
/
show errors
