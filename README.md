# plsql_utilities

A PL/SQL Utility Library

Feel free to pick and choose, or just use the code. Some of them you should keep my copyright
per the MIT license, others are already public domain.

## app_lob

Several LOB functions and procedures that should be in DBMS_LOB. The names are description enough.

- file_to_blob
- clob_to_blob
- blob_to_file

## app_log

General purpose application logging facility implemented as a User Defined Type object.

## app_parameter

General purpose application parameter set/get functionality with auditable history of changes.
Use for storing values that might otherwise be hard-coded such as email addresses,
application configuration information, and database instance specific settings (such as
might be important to differentiate between production and test environments).

## arr_varchar2_udt

User Defined Type Table of strings required for some of these utilities. If you already
have one of these, by all means use it instead. Replace all references to *arr_varchar2_udt*
in the other files you deploy.

## html_email

Provides a function to convert a cursor or query string into CLOB containing an HTML table,
as well as a procedure for sending email with a HTML body and optional attachments.

## split

A function to split a comma separated value string that follows RFC4180 
into an array of strings.
(See https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml)

Although it is overkill for the most common use cases, it handles everything the 
RFC describes with respect to quoting and is not limited to comma as a separator.
In particular if you have CSV records from Microsoft Excel, this will parse them
correctly even when they have embedded separator characters in the values. The
problem turned out to be much more complex than I thought it would be when I started.
If you like playing with regular expressions, take a gander and tell me if you can 
do better. (really! I would like to learn.)

## to_zoned_decimal

Format a number into a mainframe style Zoned Decimal. (example: 
S9(7)V99 format 6.80 => '00000068{')

## deploy.sql

Runs each of these scripts in correct order
