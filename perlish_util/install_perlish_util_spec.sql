--define d_arr_varchar2_udt="arr_varchar2_udt"
whenever sqlerror exit failure
-- specs before bodies because they intertwine
prompt calling perlish_util_udt.tps
@@perlish_util_udt.tps
prompt arr_perlish_util_udt.tps
@@arr_perlish_util_udt.tps
prompt calling perlish_util_pkg.pks
@@perlish_util_pkg.pks
