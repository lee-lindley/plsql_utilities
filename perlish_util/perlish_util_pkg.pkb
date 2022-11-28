CREATE OR REPLACE PACKAGE BODY perlish_util_pkg
IS
    -- Oracle 21c will make these mostly obsolete.
    FUNCTION hash_slice(
         p_hash     t_hash
        ,p_arr_a    &&d_arr_varchar2_udt.
    ) RETURN &&d_arr_varchar2_udt.
    IS
        v_arr       &&d_arr_varchar2_udt. := &&d_arr_varchar2_udt.();
    BEGIN
        FOR i IN 1..p_arr_a.COUNT
        LOOP
            CONTINUE WHEN NOT p_hash.EXISTS( p_arr_a(i) );
            v_arr.EXTEND;
            v_arr(v_arr.COUNT) := p_hash( p_arr_a(i) );
        END LOOP;
        return v_arr;
    END hash_slice
    ;
    FUNCTION hash_slice(
         p_hash     t_hash
        ,p_arr_a    perlish_util_udt
    ) RETURN &&d_arr_varchar2_udt.
    IS
    BEGIN
        RETURN hash_slice(p_hash, p_arr_a.get());
    END hash_slice
    ;

    PROCEDURE hash_slice_assign(
         p_hash     IN OUT NOCOPY t_hash
        ,p_arr_a    &&d_arr_varchar2_udt.
        ,p_arr_b    &&d_arr_varchar2_udt.
    ) IS
    BEGIN
        IF p_arr_a.COUNT() != p_arr_b.COUNT()
        THEN
            raise_application_error(-20112,'perlish_util_pkg.hash_slice_assign input arrays were not same size');
        END IF;
        IF p_arr_a IS NOT NULL
        THEN
            FOR i IN 1..p_arr_a.COUNT
            LOOP
                p_hash( p_arr_a(i) ) := p_arr_b(i);
            END LOOP;
        END IF;
    END hash_slice_assign
    ;

    FUNCTION hash_slice_assign(
         p_arr_a    &&d_arr_varchar2_udt.
        ,p_arr_b    &&d_arr_varchar2_udt.
    ) RETURN t_hash
    IS
        v_hash      t_hash;
    BEGIN
        hash_slice_assign(v_hash, p_arr_a, p_arr_b);
        RETURN v_hash;
    END hash_slice_assign
    ;

    PROCEDURE hash_slice_assign(
         p_hash     IN OUT NOCOPY t_hash
        ,p_arr_a    perlish_util_udt
        ,p_arr_b    perlish_util_udt
    ) IS
    BEGIN
        hash_slice_assign(p_hash, p_arr_a.get(), p_arr_b.get());
    END hash_slice_assign
    ;
    FUNCTION hash_slice_assign(
         p_arr_a    perlish_util_udt
        ,p_arr_b    perlish_util_udt
    ) RETURN t_hash
    IS
    BEGIN
        RETURN hash_slice_assign(p_arr_a.get(), p_arr_b.get());
    END hash_slice_assign
    ;

    FUNCTION cursor2hash(
        p_src   SYS_REFCURSOR
    ) RETURN t_hash
    IS
        v_indicies  &&d_arr_varchar2_udt.;
        v_values    &&d_arr_varchar2_udt.;
    BEGIN
        FETCH p_src BULK COLLECT INTO v_indicies, v_values;
        CLOSE p_src;
        RETURN hash_slice_assign(v_indicies, v_values);
    END cursor2hash
    ;

    FUNCTION query2hash(
        p_query CLOB
    ) RETURN t_hash
    IS
        v_src   SYS_REFCURSOR;
    BEGIN
        OPEN v_src FOR p_query;
        RETURN cursor2hash(v_src);
    END query2hash
    ;

    FUNCTION indicies_of(
         p_hash     t_hash
    ) RETURN &&d_arr_varchar2_udt.
    IS
        v_arr       &&d_arr_varchar2_udt. := &&d_arr_varchar2_udt.();
        v_i         BINARY_INTEGER := 1;
        v_a         VARCHAR2(4000);
    BEGIN
        IF p_hash.COUNT > 0 THEN
            v_arr.EXTEND(p_hash.COUNT);
            v_a := p_hash.FIRST;
            WHILE v_a IS NOT NULL
            LOOP
                v_arr(v_i) := v_a;
                v_i := v_i + 1;
                v_a := p_hash.NEXT(v_a);
            END LOOP;
        END IF;
        RETURN v_arr;
    END indicies_of
    ;
    FUNCTION values_of(
         p_hash     t_hash
    ) RETURN &&d_arr_varchar2_udt.
    IS
        v_arr       &&d_arr_varchar2_udt. := &&d_arr_varchar2_udt.();
        v_i         BINARY_INTEGER := 1;
        v_a         VARCHAR2(4000);
    BEGIN
        IF p_hash.COUNT > 0 THEN
            v_arr.EXTEND(p_hash.COUNT);
            v_a := p_hash.FIRST;
            WHILE v_a IS NOT NULL
            LOOP
                v_arr(v_i) := p_hash(v_a);
                v_i := v_i + 1;
                v_a := p_hash.NEXT(v_a);
            END LOOP;
        END IF;
        RETURN v_arr;
    END values_of
    ;
    FUNCTION pairs_of(
        p_hash      t_hash
    ) RETURN &&d_arr_arr_varchar2_udt.
    IS
        v_arr_arr   &&d_arr_arr_varchar2_udt. := &&d_arr_arr_varchar2_udt.();
        v_i         BINARY_INTEGER := 1;
        v_a         VARCHAR2(4000);
    BEGIN
        IF p_hash.COUNT > 0 THEN
            v_arr_arr.EXTEND(p_hash.COUNT);
            v_a := p_hash.FIRST;
            WHILE v_a IS NOT NULL
            LOOP
                v_arr_arr(v_i) := &&d_arr_varchar2_udt.( v_a, p_hash(v_a) );
                v_i := v_i + 1;
                v_a := p_hash.NEXT(v_a);
            END LOOP;
        END IF;
        RETURN v_arr_arr;
    END pairs_of
    ;
    PROCEDURE pairs_of(
        p_hash          t_hash
        ,p_indicies OUT &&d_arr_varchar2_udt.
        ,p_values   OUT &&d_arr_varchar2_udt.
    )
    IS
        v_i         BINARY_INTEGER := 1;
        v_a         VARCHAR2(4000);
    BEGIN
        p_indicies := &&d_arr_varchar2_udt.();
        p_values   := &&d_arr_varchar2_udt.();
        IF p_hash.COUNT > 0 THEN
            p_indicies.EXTEND(p_hash.COUNT);
            p_values.EXTEND(p_hash.COUNT);
            v_a := p_hash.FIRST;
            WHILE v_a IS NOT NULL
            LOOP
                p_indicies(v_i) := v_a;
                p_values(v_i) := p_hash(v_a);
                v_i := v_i + 1;
                v_a := p_hash.NEXT(v_a);
            END LOOP;
        END IF;
    END pairs_of
    ;
    
    FUNCTION get_cursor_from_collections(
        p_arr_arr       arr_perlish_util_udt
        ,p_skip_rows    NUMBER := 0
        ,p_trim_rows    NUMBER := 0
    ) RETURN SYS_REFCURSOR
    IS
        v_src           SYS_REFCURSOR;
        v_sql           CLOB;
    BEGIN
        v_sql := q'{WITH a AS (
    SELECT rownum AS rn, t.COLUMN_VALUE AS parr
    FROM TABLE(:my_tab) t
)
SELECT
    }'
            ||perlish_util_udt(p_map_string => 't.parr.get($##index_val##) AS c$##index_val##'
                               ,p_last      => p_arr_arr(1).COUNT
                              ).join(CHR(10)||'    ,')
            ||q'{
FROM a t
WHERE rn BETWEEN :first_row AND :last_row
ORDER BY rn}';

        OPEN v_src FOR v_sql USING p_arr_arr, NVL(p_skip_rows,0)+1, p_arr_arr.COUNT - NVL(p_trim_rows,0);
        RETURN v_src;
    END get_cursor_from_collections
    ;

    FUNCTION arr_perlish_from_arr_varchar2(
        p_arr_arr       &&d_arr_arr_varchar2_udt.
    ) RETURN arr_perlish_util_udt
    IS
        v_a             arr_perlish_util_udt := arr_perlish_util_udt();
    BEGIN
        v_a.EXTEND(p_arr_arr.COUNT);
        FOR i In 1..p_arr_arr.COUNT
        LOOP
            v_a(i) := perlish_util_udt(p_arr_arr(i));
        END LOOP;
        RETURN v_a;
    END;


END perlish_util_pkg;
/
show errors
