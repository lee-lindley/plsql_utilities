-- extremely annoying that Oracle has not seen fit to make public collection
-- types for varchar, number, date and clob. I am sure some egghead has a great
-- argument against it and just do not care. It is ridiculous.
whenever sqlerror exit failure
CREATE OR REPLACE TYPE arr_varchar2_udt FORCE AS TABLE OF VARCHAR2(4000);
/
GRANT EXECUTE ON arr_varchar2_udt TO PUBLIC;
