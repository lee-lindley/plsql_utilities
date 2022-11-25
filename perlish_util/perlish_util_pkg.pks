CREATE OR REPLACE PACKAGE perlish_util_pkg
IS
-- documentation at https://github.com/lee-lindley/plsql_utilities
    -- Oracle 21c will make these mostly obsolete.

    TYPE t_hash IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(4000);
    FUNCTION hash_slice(
         p_hash     t_hash
        ,p_arr_a    &&d_arr_varchar2_udt.
    ) RETURN &&d_arr_varchar2_udt.
    ;
    FUNCTION hash_slice(
         p_hash     t_hash
        ,p_arr_a    perlish_util_udt
    ) RETURN &&d_arr_varchar2_udt.
    ;
    PROCEDURE hash_slice_assign(
         p_hash     IN OUT NOCOPY t_hash
        ,p_arr_a    &&d_arr_varchar2_udt.
        ,p_arr_b    &&d_arr_varchar2_udt.
    );
    FUNCTION hash_slice_assign(
         p_arr_a    &&d_arr_varchar2_udt.
        ,p_arr_b    &&d_arr_varchar2_udt.
    ) RETURN t_hash
    ;
    PROCEDURE hash_slice_assign(
         p_hash     IN OUT NOCOPY t_hash
        ,p_arr_a    perlish_util_udt
        ,p_arr_b    perlish_util_udt
    );
    FUNCTION hash_slice_assign(
         p_arr_a    perlish_util_udt
        ,p_arr_b    perlish_util_udt
    ) RETURN t_hash
    ;

    FUNCTION cursor2hash(
        p_src   SYS_REFCURSOR
    ) RETURN t_hash
    ;
    FUNCTION query2hash(
        p_query CLOB
    ) RETURN t_hash
    ;


    FUNCTION indicies_of(
         p_hash     t_hash
    ) RETURN &&d_arr_varchar2_udt.
    ;
    FUNCTION values_of(
         p_hash     t_hash
    ) RETURN &&d_arr_varchar2_udt.
    ;

    FUNCTION pairs_of(
        p_hash      t_hash
    ) RETURN &&d_arr_arr_varchar2_udt.
    ;
    PROCEDURE pairs_of(
        p_hash          t_hash
        ,p_indicies OUT &&d_arr_varchar2_udt.
        ,p_values   OUT &&d_arr_varchar2_udt.
    )
    ;

    FUNCTION get_cursor_from_collections(
        p_arr_arr       arr_perlish_util_udt
        ,p_skip_rows    NUMBER := 0
        ,p_trim_rows    NUMBER := 0
    ) RETURN SYS_REFCURSOR
    ;
    FUNCTION arr_perlish_from_arr_varchar2(
        p_arr_arr       &&d_arr_arr_varchar2_udt.
    ) RETURN arr_perlish_util_udt
    ;


END perlish_util_pkg;
/
show errors
