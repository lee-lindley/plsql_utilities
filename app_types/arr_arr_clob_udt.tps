-- extremely annoying that Oracle has not seen fit to make public collection
-- types for varchar, number, date and clob. I am sure some egghead has a great
-- argument against it and just do not care. It is ridiculous.
whenever sqlerror exit failure
CREATE OR REPLACE TYPE &&d_arr_arr_clob_udt. FORCE AS TABLE OF &&d_arr_clob_udt.;
/
