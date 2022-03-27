# app_parameter

General purpose application parameter set/get functionality with auditable history of changes.
Use for storing values that might otherwise be hard-coded such as email addresses,
application configuration information, and database instance specific settings (as
might be important to differentiate between production and test environments).

Uses a common Data Warehouse pattern for "end dating" rather than deleting records,
thus leaving an audit trail inside the main table.
Only records with NULL *end_date* are "live" records.
Records that are logically deleted have the *end_date* and *end_dated_by*
fields populated. 
A logical update consists of a logical delete as described above plus an insert with
the fields *end_date* and *end_dated_by* set to NULL.

The standalone function *get_app_parameter* uses RESULT_CACHE with the intent of being
fast in a database with many different programs using the facility often.
That may be overkill for your scenario, but it doesn't hurt anything.
It returns NULL if the parameter name does not exist in the table.

```sql
    FUNCTION get_app_parameter(p_param_name VARCHAR2) RETURN VARCHAR2 RESULT_CACHE
```

Package *app_parameter* provides procedures for inserting and "end dating" records. A 
logical update with *create_or_replace* performs both operations. Grants to this package 
may well be different than those to *get* the parameter values.
The package provides the following public subprograms:

```sql
    -- likely seldom used, "end date" a parameter without replacing it
    PROCEDURE end_app_parameter(p_param_name VARCHAR2); 
    --
    -- both inserts and updates
    --
    PROCEDURE create_or_replace(p_param_name VARCHAR2, p_param_value VARCHAR2);

    -- these are specialized for a scenario where production data is cloned to a test system 
    -- and you do not want the parameters from production used to do bad things in the test system
    -- before you get a chance to update them. Obscure and perhaps not useful to you.
    FUNCTION is_matching_database RETURN BOOLEAN;
    FUNCTION get_database_match RETURN VARCHAR2;
    PROCEDURE set_database_match; -- do this after updating the other app_parameters following a db refresh from production
```

The implemenation includes two triggers to prevent a well meaning coworker from performing invalid
updates or deletes rather than using the procedures (or doing them correctly). These
also add the userid and timestamp for new records that do not have values provided.
This level of control is likely overkill, but it is nice to be able to
tell an auditor or security reviewer that you have auditable change history on an important table 
that you will probably want to be able to update in production without a code promotion.
