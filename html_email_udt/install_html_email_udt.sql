-- Personal preference. comment these out if your DBA complains or
-- if you have an issue with the limits for amount of native code
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
--
-- REQUIRES: split
--      if you do not want to deploy mine, set use_split to FALSE
--      and we will use a simpler function internal to the type.
-- REQUIRES: arr_varchar2_udt
--      If you have your own you can easily substitute it in the code yourself.
--          Otherwise, deploy the one provided.
--
-- We optionally use app_parameter and app_log based on compile directives:
-- We optionally deploy and use a package named mime_type. If you do not want it,
-- set use_mime_type to FALSE and it will not deploy. Default mime_type values
-- should be fine.
----------------------------------------------------------------------------
--ALTER SESSION SET PLSQL_CCFLAGS='use_app_log:TRUE,use_app_parameter:TRUE,use_mime_type:TRUE,use_split:TRUE';
----------------------------------------------------------------------------
BEGIN
$if $$use_app_parameter $then
    DBMS_OUTPUT.put_line('use_app_parameter is TRUE');
$else
    DBMS_OUTPUT.put_line('use_app_parameter is FALSE');
$end
$if $$use_app_log $then
    DBMS_OUTPUT.put_line('use_app_log is TRUE');
$else
    DBMS_OUTPUT.put_line('use_app_log is FALSE');
$end
$if $$use_mime_type $then
    DBMS_OUTPUT.put_line('use_mime_type is TRUE');
$else
    DBMS_OUTPUT.put_line('use_mime_type is FALSE');
$end
$if $$use_split $then
    DBMS_OUTPUT.put_line('use_split is TRUE');
$else
    DBMS_OUTPUT.put_line('use_split is FALSE');
$end
END;
/
/*
    NOTE: you must have priv to write to the network. This is a big subject. 
    Here is what I did as sysdba in order for my account (lee) to be able to
    write to port 25 on the RedHat Linux server my Oracle database runs upon. 
    Assuming you have an smtp server somewhere other than your database server 
    like most sane organizations, you will need the ACL entry for that host 
    and the schema where you are deploying this. If not you will get:

        ORA-24247: network access denied by access control list (ACL)
    
    when you try to send an email. This is true even though we are writing 
    to localhost!

    port 25 was open in my RHL firewalld for outgoing. YMMV.

begin
    dbms_network_acl_admin.append_host_ace(
        host => 'localhost'
        ,lower_port => NULL
        ,upper_port => NULL
        ,ace => xs$ace_type(
            privilege_list => xs$name_list('smtp')
            ,principal_name => 'lee'
            ,principal_type => xs_acl.ptype_db
        )
    );
end;
<-- the slash goes here but sqlplus eats it and pukes even inside comment
*/
whenever sqlerror continue
-- the attachment type has a dependency
DROP TYPE html_email_udt;
prompt ok if type drop failed for not exists
DROP TYPE arr_email_attachment_udt;
prompt ok if type drop failed for not exists
whenever sqlerror exit failure
--
prompt Beginning anonymous block for mime_type_pkg
prompt will not deploy unless compile directive use_mime_type=TRUE
@&&subdir/mime_type.pks
prompt Beginning anonymous block for mime_type_pkg body
prompt will not deploy unless compile directive use_mime_type=TRUE
@&&subdir/mime_type.pkb
--
--
prompt create email_attachment_udt
@&&subdir/email_attachment_udt.tps
prompt create body email_attachment_udt
@&&subdir/email_attachment_udt.tpb
prompt create arr_email_attachment_udt
@&&subdir/arr_email_attachment_udt.tps
--
-- oh my, how embarrasing for Oracle. You cannot use compile directives in the
-- definition of a user defined type object. You can use them just fine in the
-- body, but not in creating the type itself (type specification). We will use 
-- the compile directives to create a character string that we feed to execute
-- immediate. Such a damn hack. Shame Oracle! Shame!
-- At least the hack is only for deployment code. I can live with it.
--
prompt begin anonymous block create html_email_udt spec
@&&subdir/html_email_udt.tps
prompt create html_email_udt body
@&&subdir/html_email_udt.tpb
ALTER SESSION SET plsql_optimize_level=2;
ALTER SESSION SET plsql_code_type = INTERPRETED;
-- NOT granting to public. could spam
--GRANT EXECUTE ON html_email_udt TO ???;
prompt deployment of html_email_udt and supporting types and packages is complete
