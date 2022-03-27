# plsql_utilities

An Oracle PL/SQL Utility Library

Feel free to pick and choose, or just borrow code. Some of them you should keep my copyright
per the MIT license, others are already public domain. Included are

* Application Logging
* Application Parameter Facility
* Perlish Utility User Defined Type
    * Transforming Perl-style Regexp to Oracle RE
    * methods that mimic the Perl *map*, *join* and *sort* methods in a chain of calls
* CSV data handling
* Create Zoned Decimal Strings from Numbers
* A few LOB Utilities
* A zip archive handler courtesy of Anton Scheffer
* An Object wrapper for *as_zip*
* A wrapper for DBMS_SQL that handles bulk fetches (likely superceded by Polymorphic Table Functions)

# Content

1. [install.sql](#installsql)
2. [Packages and Types](#packages-and-types)

## install.sql

*install.sql* runs each of these scripts in correct order.

There are sqlplus *define* statements at the top of the script for naming basic collection types.
In this document I refer to them with **arr\_X\_udt** names, but you can follow your own naming guidelines
for them. If you already have types with the same characteristics, put those into the *define* statements
and then set the corresponding **compile\*** define values to FALSE.

Dependencies are depicted in the component diagram, but repeated here.

*perlish_util_pkg* depends on *arr_varchar2_udt* and *arr_arr_varchar2_udt*.

*perlish_util_udt* depends on *arr_varchar2_udt* and *app_csv_pkg*.

*app_csv_pkg* depends on on *app_lob* and *arr_varchar2_udt*. Much of the functionality also requires Oracle verision 18 or higher.

*app_zip* depends on *as_zip*, *app_lob*, *arr_varchar2_udt*, and *app_csv_pkg*.

*app_job_log* depends on *app_log*, and optionally on [html_email](https://github.com/lee-lindley/html_email)
if you set the compile directive define use_html_email to 'TRUE' in *app_job_log/install_app_job_log.sql*.

Other than those, you can compile these separately or not at all. If you run *install.sql*
as is, it will install 10 of the 11 components (and sub-components).

The compile for *app_dbms_sql* is set to FALSE. It is generally compiled from a repository
that includes *plsql_utilities* as a submodule. It requires *arr_arr_clob_udt*, *arr_clob_udt*, *arr_integer_udt*, and *arr_varchar2_udt*.

## Packages and Types

| ![plsql_utilities_component_diagram.gif](images/plsql_utilities_component_diagram.gif) |
|:--:|
| Plsql Utilities Component Diagram |

Each component has a separate directory and README.md.

- [app_csv_pkg](app_csv_pkg/)
- [app_lob](app_lob/)
- [app_log](app_log/)
- [app_job_log](app_job_log/)
- [app_parameter](app_parameter/)
- [app_types](app_types/)
- [perlish_util](perlish_util/)
- [to_zoned_decimal](misc/)
- [as_zip](as_zip/)
- [app_zip](app_zip/)
- [app_dbms_sql](app_dbms_sql/)
