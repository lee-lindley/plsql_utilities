CREATE OR REPLACE TYPE BODY app_part_exchg_udt
IS
    CONSTRUCTOR FUNCTION app_part_exchg_udt(
        p_table_name        VARCHAR2
        ,p_schema_name      VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
    ) RETURN SELF AS RESULT
    IS
        v_handle        NUMBER;
        v_thandle       NUMBER;
        v_det           app_part_exchg_det_udt;
        v_unique_cnt    NUMBER;
        multiple_unique_indexes EXCEPTION;
        foreign_key_constraint  EXCEPTION;
        non_partitioned_constraint  EXCEPTION;
        PRAGMA exception_init(multiple_unique_indexes, -20885);
        PRAGMA exception_init(foreign_key_constraint, -20886);
        PRAGMA exception_init(non_partitioned_constraint, -20887);
    BEGIN 
        table_name  := p_table_name;
        schema_name := p_schema_name;
        -- if longer than 27 characters, take the last 27; otherwise start at 1
        swap_name   := 'SWP'||SUBSTR(p_table_name, GREATEST(LENGTH(p_table_name) - 26, 1) );

        --
        -- See if there is anything about the table that we cannot handle (yet)
        --

        -- if not found will raise exception
        SELECT partitioned INTO SELF.partitioned 
        FROM all_tables 
        WHERE table_name = p_table_name AND owner = p_schema_name
        ;
        -- we cannot yet support foreign key constraints. Needs research
        SELECT COUNT(*) INTO v_unique_cnt
        FROM all_constraints
        WHERE table_name = p_table_name AND owner = p_schema_name
            AND constraint_type NOT IN ('C','P','U')
        ;
        IF v_unique_cnt > 1 THEN
            raise_application_error(-20886,'app_part_exchg_udt does not support foreign key constraints. table: '||p_table_name||' count unsupported constraints: '||TO_CHAR(v_unique_cnt));
        END IF;

        IF partitioned = 'YES' THEN
            -- need to check if partitioned table with non-partitioned constraint index
            SELECT COUNT(*) INTO v_unique_cnt
            FROM all_indexes
            WHERE table_name = p_table_name AND owner = p_schema_name
                AND partitioned = 'NO' AND constraint_index = 'YES'
            ;
            IF v_unique_cnt > 1 THEN
                raise_application_error(-20887,'app_part_exchg_udt does not support non-partitioned constraint indexes on partitioned table. table: '||p_table_name||' count non-parititoned constaint indexes: '||TO_CHAR(v_unique_cnt));
            END IF;
        END IF;

        --
        -- This one must come after other temporary uses of v_unique_cnt.
        --
        -- we cannot yet support multiple unique indexes. Would involve disabling and rebuilding after partition exchange
        SELECT COUNT(*) INTO v_unique_cnt
        FROM all_indexes
        WHERE table_name = p_table_name AND owner = p_schema_name
            AND uniqueness = 'UNIQUE'
        ;
        IF v_unique_cnt > 1 THEN
            raise_application_error(-20885,'app_part_exchg_udt does not support multiple unique indexes. table: '||p_table_name||' count unique indexes: '||TO_CHAR(v_unique_cnt));
        END IF;

        --
        -- Looks like we can do this. Start building our ddl statements
        --
        ddls := app_part_exchg_det_arr_udt();
        ddls.EXTEND;
        -- first ddl is to drop swap table if already exists
        v_det := app_part_exchg_det_udt();
        v_det.type      := 'DROP';
        v_det.ddl       := 'DROP TABLE '||swap_name;
        v_det.can_fail  := 'Y';
        ddls(1) := v_det;

        -- prepare transforms for table metadata
        v_handle := DBMS_METADATA.OPEN('TABLE');
        DBMS_METADATA.set_filter(v_handle, 'SCHEMA', schema_name);
        DBMS_METADATA.set_filter(v_handle, 'NAME', table_name);

        -- rename table transform
        v_thandle := DBMS_METADATA.add_transform(v_handle, 'MODIFY');
        DBMS_METADATA.SET_REMAP_PARAM(v_thandle,'REMAP_NAME',table_name,swap_name);  

        -- regular ddl transforms
        v_thandle := DBMS_METADATA.add_transform(v_handle, 'DDL');
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'SQLTERMINATOR',FALSE);  
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'TABLESPACE',FALSE);  
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'PRETTY',TRUE);  
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'STORAGE',FALSE);  
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'SEGMENT_ATTRIBUTES',FALSE);  
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'PARTITIONING',FALSE);  
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'EMIT_SCHEMA',FALSE);  
        DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'CONSTRAINTS',FALSE);  
        --DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'CONSTRAINTS_AS_ALTER',TRUE);  
        --DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'CONSTRAINT_USE_DEFAULT_INDEX',TRUE);  
        -- no way to get just the constraints that are not supported by indexes. Must do them all separately


        v_det := app_part_exchg_det_udt();
        v_det.type := 'TABLE';
        v_det.can_fail := 'N';
        v_det.ddl := DBMS_METADATA.fetch_clob(v_handle);
        DBMS_METADATA.close(v_handle);
        IF partitioned != 'YES' THEN -- the swap table must be partitioned if target table is not
            DECLARE
                l_cols   VARCHAR2(4000);
            BEGIN
                IF v_unique_cnt > 0 THEN 
                    -- if there is a unique key, partition on the key value(s).
                    SELECT LISTAGG('"'||c.column_name||'"', ',') WITHIN GROUP(ORDER BY c.column_position) AS c
                        INTO l_cols
                    FROM all_indexes i
                    INNER JOIN all_ind_columns c
                        ON c.index_owner = i.owner AND c.index_name = i.index_name
                    WHERE i.table_name = p_table_name AND i.owner = p_schema_name
                        AND i.uniqueness = 'UNIQUE'
                    ;
                ELSE
                    -- if no unique key, pick arbitrary column to do range partitioning. 
                    SELECT MAX('"'||column_name||'"') KEEP (DENSE_RANK FIRST ORDER BY column_id) AS c
                        INTO l_cols
                    FROM all_tab_columns
                    WHERE table_name = p_table_name AND owner = p_schema_name
                        AND (data_type IN ('NUMBER', 'VARCHAR2', 'DATE') OR data_type LIKE 'TIMESTAMP%')
                    ;
                END IF;
                -- range partitioning on the unique key if any, or any column of a reasonable type. Single partition.
                v_det.ddl := v_det.ddl || ' PARTITION BY RANGE('||l_cols||') (PARTITION P1 VALUES LESS THAN (MAXVALUE))';
            END;
        END IF;
        ddls.EXTEND;
        ddls(ddls.COUNT) := v_det;

        -- we want the non-index "check" constraints first as we will put them on the table before populating it.
        -- Then any unique or PK constraints as those add an index
        FOR r IN (
            SELECT constraint_name, constraint_type
            FROM all_constraints
            WHERE table_name = p_table_name AND owner = p_schema_name
                AND constraint_type IN ('C','P','U')
            ORDER BY CASE WHEN constraint_type = 'C' THEN 1 ELSE 2 END, constraint_name
        ) LOOP
            v_handle := DBMS_METADATA.OPEN('CONSTRAINT');
            DBMS_METADATA.set_filter(v_handle, 'SCHEMA', schema_name);
            DBMS_METADATA.set_filter(v_handle, 'NAME', r.constraint_name);

            -- rename transform
            v_thandle := DBMS_METADATA.add_transform(v_handle, 'MODIFY');
            DBMS_METADATA.SET_REMAP_PARAM(v_thandle,'REMAP_NAME'
                                            ,r.constraint_name
                                            ,'SWP'||SUBSTR(r.constraint_name,GREATEST(LENGTH(r.constraint_name) - 26, 1))
                                         );
            DBMS_METADATA.SET_REMAP_PARAM(v_thandle,'REMAP_NAME',table_name,swap_name);  

            -- regular ddl transforms
            v_thandle := DBMS_METADATA.add_transform(v_handle, 'DDL');
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'SQLTERMINATOR',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'TABLESPACE',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'PRETTY',TRUE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'STORAGE',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'SEGMENT_ATTRIBUTES',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'PARTITIONING',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'EMIT_SCHEMA',FALSE);  
            --DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'CONSTRAINT_USE_DEFAULT_INDEX',TRUE);  

            v_det := app_part_exchg_det_udt();
            -- even though the PK or Unique constraint is a constraint, it creates an index so we lump it in with those
            v_det.type := CASE r.constraint_type WHEN 'C' THEN 'CONSTRAINT' ELSE 'INDEX' END;
            v_det.can_fail := 'N';
            v_det.ddl := REPLACE(DBMS_METADATA.fetch_clob(v_handle)
                                    ,'ENABLE'
                                    ,CASE WHEN partitioned <> 'YES' AND r.constraint_type <> 'C' 
                                            THEN 'LOCAL ENABLE' 
                                            ELSE 'ENABLE' 
                                     END
                                );

            DBMS_METADATA.close(v_handle);
    
            ddls.EXTEND;
            ddls(ddls.COUNT) := v_det;
        END LOOP;

        -- now need to get the indexes. Want only partitioned indexes if table is partitioned.
        -- We already dealt with the indexes associated with constraints.
        FOR r IN (SELECT index_name 
                    FROM all_indexes
                    WHERE table_owner = SELF.schema_name AND table_name = SELF.table_name
                        AND (partitioned = 'YES' OR SELF.partitioned = 'NO')
                        AND constraint_index = 'NO'
        ) LOOP
            v_handle := DBMS_METADATA.OPEN('INDEX');
            DBMS_METADATA.set_filter(v_handle, 'SCHEMA', schema_name);
            DBMS_METADATA.set_filter(v_handle, 'NAME', r.index_name);

            -- rename transform
            v_thandle := DBMS_METADATA.add_transform(v_handle, 'MODIFY');
            DBMS_METADATA.SET_REMAP_PARAM(v_thandle,'REMAP_NAME'
                                            ,r.index_name
                                            ,'SWP'||SUBSTR(r.index_name,GREATEST(LENGTH(r.index_name) - 26, 1))
                                         );
            DBMS_METADATA.SET_REMAP_PARAM(v_thandle,'REMAP_NAME',table_name,swap_name);  

            -- regular ddl transforms
            v_thandle := DBMS_METADATA.add_transform(v_handle, 'DDL');
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'SQLTERMINATOR',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'TABLESPACE',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'PRETTY',TRUE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'STORAGE',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'SEGMENT_ATTRIBUTES',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'PARTITIONING',FALSE);  
            DBMS_METADATA.SET_TRANSFORM_PARAM(v_thandle,'EMIT_SCHEMA',FALSE);  
    
            v_det := app_part_exchg_det_udt();
            v_det.type := 'INDEX';
            v_det.can_fail := 'N';
            v_det.ddl := DBMS_METADATA.fetch_clob(v_handle)
                             || CASE WHEN partitioned <> 'YES' THEN ' LOCAL ' END
            ;

            DBMS_METADATA.close(v_handle);
    
            ddls.EXTEND;
            ddls(ddls.COUNT) := v_det;
        END LOOP;
        RETURN;
    END app_part_exchg_udt
    ;
    MEMBER PROCEDURE print_ddl
    IS
    BEGIN
        DBMS_OUTPUT.put_line('schema_name: '||schema_name||'
table_name: '||table_name||'
swap_name: '||swap_name||'
partitioned: '||partitioned
        );
        FOR i IN 1..ddls.COUNT
        LOOP
            DBMS_OUTPUT.put_line('    i='||TO_CHAR(i)||'
    type: '||ddls(i).type||'
    can_fail: '||ddls(i).can_fail||'
    ddl: '||ddls(i).ddl
            );
        END LOOP;
    END print_ddl
    ;
END 
;
/
show errors
