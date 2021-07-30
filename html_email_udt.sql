-- REQUIRES: split
--      if you do not want to deploy mine, deploy your own or create a local
--      static function.
-- REQUIRES: arr_varchar2_udt
--      If you have your own you can easily substitute it in the code yourself.
--
-- We optionally use app_parameter and app_log based on compile directives:
-- We optionally deploy and use a package named mime_type.
--ALTER SESSION SET PLSQL_CCFLAGS='use_app_log:TRUE,use_app_parameter:TRUE,use_mime_type:TRUE';
--
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
END;
/
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
--
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
<-- the slash goes here but sqlplus hates it even inside comment
*/
whenever sqlerror continue
-- the attachment type has a dependency
DROP TYPE html_email_udt;
prompt ok if type drop failed for not exists
DROP TYPE arr_html_email_attachment_udt;
prompt ok if type drop failed for not exists
whenever sqlerror exit failure
BEGIN
    -- we use a trick with anonymous block and plsql compile directives
    -- to determine whether or not to deploy package mime_type
$if $$use_mime_type $then
    EXECUTE IMMEDIATE q'[
CREATE OR REPLACE PACKAGE mime_type IS
    FUNCTION get(
        p_filename              VARCHAR2
        ,p_use_binary_default   VARCHAR2 := NULL -- Y or not Y
    ) RETURN VARCHAR2;
    -- can provide extension with no dot, .extension, or full filename
    -- if extension not found or there is not one in your file name
    -- will return text/plain (or application/octet-stream if use_binary=Y)
END mime_type;]';
    EXECUTE IMMEDIATE q'[
CREATE OR REPLACE PACKAGE BODY mime_type IS
    TYPE t_mime_types IS TABLE of VARCHAR2(100) INDEX BY VARCHAR2(24);
    g_mime_types    t_mime_types;

    FUNCTION get(
        p_filename              VARCHAR2
        ,p_use_binary_default   VARCHAR2 := NULL -- Y,y or not 
    ) RETURN VARCHAR2
    IS
        v_extension VARCHAR2(32767);
        v_default VARCHAR2(100) := CASE WHEN UPPER(p_use_binary_default) = 'Y'
                                        THEN 'application/octet-stream'
                                        ELSE 'text/plain'
                                    END;
    BEGIN
        v_extension := LOWER(REGEXP_SUBSTR(p_filename, '\.?([^.]+?)$',1,1,NULL,1));
        -- txt, x.txt, and x.y.txt all work fine
        IF LENGTH(v_extension) > 20 THEN
            RETURN v_default; -- probably just a filename with no dot
        ELSIF g_mime_types.EXISTS(v_extension) THEN
            RETURN g_mime_types(v_extension);
        ELSE
            RETURN v_default;
        END IF;
    END get;

    BEGIN -- the rare bare begin in a package body definition

    -- load with package
    g_mime_types('123') := 'application/vnd.lotus-1-2-3';
    g_mime_types('3dml') := 'text/vnd.in3d.3dml';
    g_mime_types('3ds') := 'image/x-3ds';
    g_mime_types('3g2') := 'video/3gpp2';
    g_mime_types('3gp') := 'video/3gpp';
    g_mime_types('7z') := 'application/x-7z-compressed';
    g_mime_types('aab') := 'application/x-authorware-bin';
    g_mime_types('aac') := 'audio/x-aac';
    g_mime_types('aam') := 'application/x-authorware-map';
    g_mime_types('aas') := 'application/x-authorware-seg';
    g_mime_types('abw') := 'application/x-abiword';
    g_mime_types('ac') := 'application/pkix-attr-cert';
    g_mime_types('acc') := 'application/vnd.americandynamics.acc';
    g_mime_types('ace') := 'application/x-ace-compressed';
    g_mime_types('acu') := 'application/vnd.acucobol';
    g_mime_types('acutc') := 'application/vnd.acucorp';
    g_mime_types('adp') := 'audio/adpcm';
    g_mime_types('aep') := 'application/vnd.audiograph';
    g_mime_types('afm') := 'application/x-font-type1';
    g_mime_types('afp') := 'application/vnd.ibm.modcap';
    g_mime_types('ahead') := 'application/vnd.ahead.space';
    g_mime_types('ai') := 'application/postscript';
    g_mime_types('aif') := 'audio/x-aiff';
    g_mime_types('aifc') := 'audio/x-aiff';
    g_mime_types('aiff') := 'audio/x-aiff';
    g_mime_types('air') := 'application/vnd.adobe.air-application-installer-package+zip';
    g_mime_types('ait') := 'application/vnd.dvb.ait';
    g_mime_types('ami') := 'application/vnd.amiga.ami';
    g_mime_types('apk') := 'application/vnd.android.package-archive';
    g_mime_types('appcache') := 'text/cache-manifest';
    g_mime_types('application') := 'application/x-ms-application';
    g_mime_types('apr') := 'application/vnd.lotus-approach';
    g_mime_types('arc') := 'application/x-freearc';
    g_mime_types('asc') := 'application/pgp-signature';
    g_mime_types('asf') := 'video/x-ms-asf';
    g_mime_types('asm') := 'text/x-asm';
    g_mime_types('aso') := 'application/vnd.accpac.simply.aso';
    g_mime_types('asx') := 'video/x-ms-asf';
    g_mime_types('atc') := 'application/vnd.acucorp';
    g_mime_types('atom') := 'application/atom+xml';
    g_mime_types('atomcat') := 'application/atomcat+xml';
    g_mime_types('atomsvc') := 'application/atomsvc+xml';
    g_mime_types('atx') := 'application/vnd.antix.game-component';
    g_mime_types('au') := 'audio/basic';
    g_mime_types('avi') := 'video/x-msvideo';
    g_mime_types('aw') := 'application/applixware';
    g_mime_types('azf') := 'application/vnd.airzip.filesecure.azf';
    g_mime_types('azs') := 'application/vnd.airzip.filesecure.azs';
    g_mime_types('azw') := 'application/vnd.amazon.ebook';
    g_mime_types('bat') := 'application/x-msdownload';
    g_mime_types('bcpio') := 'application/x-bcpio';
    g_mime_types('bdf') := 'application/x-font-bdf';
    g_mime_types('bdm') := 'application/vnd.syncml.dm+wbxml';
    g_mime_types('bed') := 'application/vnd.realvnc.bed';
    g_mime_types('bh2') := 'application/vnd.fujitsu.oasysprs';
    g_mime_types('bin') := 'application/octet-stream';
    g_mime_types('blb') := 'application/x-blorb';
    g_mime_types('blorb') := 'application/x-blorb';
    g_mime_types('bmi') := 'application/vnd.bmi';
    g_mime_types('bmp') := 'image/bmp';
    g_mime_types('book') := 'application/vnd.framemaker';
    g_mime_types('box') := 'application/vnd.previewsystems.box';
    g_mime_types('boz') := 'application/x-bzip2';
    g_mime_types('bpk') := 'application/octet-stream';
    g_mime_types('btif') := 'image/prs.btif';
    g_mime_types('bz') := 'application/x-bzip';
    g_mime_types('bz2') := 'application/x-bzip2';
    g_mime_types('c') := 'text/x-c';
    g_mime_types('c11amc') := 'application/vnd.cluetrust.cartomobile-config';
    g_mime_types('c11amz') := 'application/vnd.cluetrust.cartomobile-config-pkg';
    g_mime_types('c4d') := 'application/vnd.clonk.c4group';
    g_mime_types('c4f') := 'application/vnd.clonk.c4group';
    g_mime_types('c4g') := 'application/vnd.clonk.c4group';
    g_mime_types('c4p') := 'application/vnd.clonk.c4group';
    g_mime_types('c4u') := 'application/vnd.clonk.c4group';
    g_mime_types('cab') := 'application/vnd.ms-cab-compressed';
    g_mime_types('caf') := 'audio/x-caf';
    g_mime_types('cap') := 'application/vnd.tcpdump.pcap';
    g_mime_types('car') := 'application/vnd.curl.car';
    g_mime_types('cat') := 'application/vnd.ms-pki.seccat';
    g_mime_types('cb7') := 'application/x-cbr';
    g_mime_types('cba') := 'application/x-cbr';
    g_mime_types('cbr') := 'application/x-cbr';
    g_mime_types('cbt') := 'application/x-cbr';
    g_mime_types('cbz') := 'application/x-cbr';
    g_mime_types('cc') := 'text/x-c';
    g_mime_types('cct') := 'application/x-director';
    g_mime_types('ccxml') := 'application/ccxml+xml';
    g_mime_types('cdbcmsg') := 'application/vnd.contact.cmsg';
    g_mime_types('cdf') := 'application/x-netcdf';
    g_mime_types('cdkey') := 'application/vnd.mediastation.cdkey';
    g_mime_types('cdmia') := 'application/cdmi-capability';
    g_mime_types('cdmic') := 'application/cdmi-container';
    g_mime_types('cdmid') := 'application/cdmi-domain';
    g_mime_types('cdmio') := 'application/cdmi-object';
    g_mime_types('cdmiq') := 'application/cdmi-queue';
    g_mime_types('cdx') := 'chemical/x-cdx';
    g_mime_types('cdxml') := 'application/vnd.chemdraw+xml';
    g_mime_types('cdy') := 'application/vnd.cinderella';
    g_mime_types('cer') := 'application/pkix-cert';
    g_mime_types('cfs') := 'application/x-cfs-compressed';
    g_mime_types('cgm') := 'image/cgm';
    g_mime_types('chat') := 'application/x-chat';
    g_mime_types('chm') := 'application/vnd.ms-htmlhelp';
    g_mime_types('chrt') := 'application/vnd.kde.kchart';
    g_mime_types('cif') := 'chemical/x-cif';
    g_mime_types('cii') := 'application/vnd.anser-web-certificate-issue-initiation';
    g_mime_types('cil') := 'application/vnd.ms-artgalry';
    g_mime_types('cla') := 'application/vnd.claymore';
    g_mime_types('class') := 'application/java-vm';
    g_mime_types('clkk') := 'application/vnd.crick.clicker.keyboard';
    g_mime_types('clkp') := 'application/vnd.crick.clicker.palette';
    g_mime_types('clkt') := 'application/vnd.crick.clicker.template';
    g_mime_types('clkw') := 'application/vnd.crick.clicker.wordbank';
    g_mime_types('clkx') := 'application/vnd.crick.clicker';
    g_mime_types('clp') := 'application/x-msclip';
    g_mime_types('cmc') := 'application/vnd.cosmocaller';
    g_mime_types('cmdf') := 'chemical/x-cmdf';
    g_mime_types('cml') := 'chemical/x-cml';
    g_mime_types('cmp') := 'application/vnd.yellowriver-custom-menu';
    g_mime_types('cmx') := 'image/x-cmx';
    g_mime_types('cod') := 'application/vnd.rim.cod';
    g_mime_types('com') := 'application/x-msdownload';
    g_mime_types('conf') := 'text/plain';
    g_mime_types('cpio') := 'application/x-cpio';
    g_mime_types('cpp') := 'text/x-c';
    g_mime_types('cpt') := 'application/mac-compactpro';
    g_mime_types('crd') := 'application/x-mscardfile';
    g_mime_types('crl') := 'application/pkix-crl';
    g_mime_types('crt') := 'application/x-x509-ca-cert';
    g_mime_types('cryptonote') := 'application/vnd.rig.cryptonote';
    g_mime_types('csh') := 'application/x-csh';
    g_mime_types('csml') := 'chemical/x-csml';
    g_mime_types('csp') := 'application/vnd.commonspace';
    g_mime_types('css') := 'text/css';
    g_mime_types('cst') := 'application/x-director';
    g_mime_types('csv') := 'text/csv';
    g_mime_types('cu') := 'application/cu-seeme';
    g_mime_types('curl') := 'text/vnd.curl';
    g_mime_types('cww') := 'application/prs.cww';
    g_mime_types('cxt') := 'application/x-director';
    g_mime_types('cxx') := 'text/x-c';
    g_mime_types('dae') := 'model/vnd.collada+xml';
    g_mime_types('daf') := 'application/vnd.mobius.daf';
    g_mime_types('dart') := 'application/vnd.dart';
    g_mime_types('dataless') := 'application/vnd.fdsn.seed';
    g_mime_types('davmount') := 'application/davmount+xml';
    g_mime_types('dbk') := 'application/docbook+xml';
    g_mime_types('dcr') := 'application/x-director';
    g_mime_types('dcurl') := 'text/vnd.curl.dcurl';
    g_mime_types('dd2') := 'application/vnd.oma.dd2+xml';
    g_mime_types('ddd') := 'application/vnd.fujixerox.ddd';
    g_mime_types('deb') := 'application/x-debian-package';
    g_mime_types('def') := 'text/plain';
    g_mime_types('deploy') := 'application/octet-stream';
    g_mime_types('der') := 'application/x-x509-ca-cert';
    g_mime_types('dfac') := 'application/vnd.dreamfactory';
    g_mime_types('dgc') := 'application/x-dgc-compressed';
    g_mime_types('dic') := 'text/x-c';
    g_mime_types('dir') := 'application/x-director';
    g_mime_types('dis') := 'application/vnd.mobius.dis';
    g_mime_types('dist') := 'application/octet-stream';
    g_mime_types('distz') := 'application/octet-stream';
    g_mime_types('djv') := 'image/vnd.djvu';
    g_mime_types('djvu') := 'image/vnd.djvu';
    g_mime_types('dll') := 'application/x-msdownload';
    g_mime_types('dmg') := 'application/x-apple-diskimage';
    g_mime_types('dmp') := 'application/vnd.tcpdump.pcap';
    g_mime_types('dms') := 'application/octet-stream';
    g_mime_types('dna') := 'application/vnd.dna';
    g_mime_types('doc') := 'application/msword';
    g_mime_types('docm') := 'application/vnd.ms-word.document.macroenabled.12';
    g_mime_types('docx') := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    g_mime_types('dot') := 'application/msword';
    g_mime_types('dotm') := 'application/vnd.ms-word.template.macroenabled.12';
    g_mime_types('dotx') := 'application/vnd.openxmlformats-officedocument.wordprocessingml.template';
    g_mime_types('dp') := 'application/vnd.osgi.dp';
    g_mime_types('dpg') := 'application/vnd.dpgraph';
    g_mime_types('dra') := 'audio/vnd.dra';
    g_mime_types('dsc') := 'text/prs.lines.tag';
    g_mime_types('dssc') := 'application/dssc+der';
    g_mime_types('dtb') := 'application/x-dtbook+xml';
    g_mime_types('dtd') := 'application/xml-dtd';
    g_mime_types('dts') := 'audio/vnd.dts';
    g_mime_types('dtshd') := 'audio/vnd.dts.hd';
    g_mime_types('dump') := 'application/octet-stream';
    g_mime_types('dvb') := 'video/vnd.dvb.file';
    g_mime_types('dvi') := 'application/x-dvi';
    g_mime_types('dwf') := 'model/vnd.dwf';
    g_mime_types('dwg') := 'image/vnd.dwg';
    g_mime_types('dxf') := 'image/vnd.dxf';
    g_mime_types('dxp') := 'application/vnd.spotfire.dxp';
    g_mime_types('dxr') := 'application/x-director';
    g_mime_types('ecelp4800') := 'audio/vnd.nuera.ecelp4800';
    g_mime_types('ecelp7470') := 'audio/vnd.nuera.ecelp7470';
    g_mime_types('ecelp9600') := 'audio/vnd.nuera.ecelp9600';
    g_mime_types('ecma') := 'application/ecmascript';
    g_mime_types('edm') := 'application/vnd.novadigm.edm';
    g_mime_types('edx') := 'application/vnd.novadigm.edx';
    g_mime_types('efif') := 'application/vnd.picsel';
    g_mime_types('ei6') := 'application/vnd.pg.osasli';
    g_mime_types('elc') := 'application/octet-stream';
    g_mime_types('emf') := 'application/x-msmetafile';
    g_mime_types('eml') := 'message/rfc822';
    g_mime_types('emma') := 'application/emma+xml';
    g_mime_types('emz') := 'application/x-msmetafile';
    g_mime_types('eol') := 'audio/vnd.digital-winds';
    g_mime_types('eot') := 'application/vnd.ms-fontobject';
    g_mime_types('eps') := 'application/postscript';
    g_mime_types('epub') := 'application/epub+zip';
    g_mime_types('es3') := 'application/vnd.eszigno3+xml';
    g_mime_types('esa') := 'application/vnd.osgi.subsystem';
    g_mime_types('esf') := 'application/vnd.epson.esf';
    g_mime_types('et3') := 'application/vnd.eszigno3+xml';
    g_mime_types('etx') := 'text/x-setext';
    g_mime_types('eva') := 'application/x-eva';
    g_mime_types('evy') := 'application/x-envoy';
    g_mime_types('exe') := 'application/x-msdownload';
    g_mime_types('exi') := 'application/exi';
    g_mime_types('ext') := 'application/vnd.novadigm.ext';
    g_mime_types('ez') := 'application/andrew-inset';
    g_mime_types('ez2') := 'application/vnd.ezpix-album';
    g_mime_types('ez3') := 'application/vnd.ezpix-package';
    g_mime_types('f') := 'text/x-fortran';
    g_mime_types('f4v') := 'video/x-f4v';
    g_mime_types('f77') := 'text/x-fortran';
    g_mime_types('f90') := 'text/x-fortran';
    g_mime_types('fbs') := 'image/vnd.fastbidsheet';
    g_mime_types('fcdt') := 'application/vnd.adobe.formscentral.fcdt';
    g_mime_types('fcs') := 'application/vnd.isac.fcs';
    g_mime_types('fdf') := 'application/vnd.fdf';
    g_mime_types('fe_launch') := 'application/vnd.denovo.fcselayout-link';
    g_mime_types('fg5') := 'application/vnd.fujitsu.oasysgp';
    g_mime_types('fgd') := 'application/x-director';
    g_mime_types('fh') := 'image/x-freehand';
    g_mime_types('fh4') := 'image/x-freehand';
    g_mime_types('fh5') := 'image/x-freehand';
    g_mime_types('fh7') := 'image/x-freehand';
    g_mime_types('fhc') := 'image/x-freehand';
    g_mime_types('fig') := 'application/x-xfig';
    g_mime_types('flac') := 'audio/x-flac';
    g_mime_types('fli') := 'video/x-fli';
    g_mime_types('flo') := 'application/vnd.micrografx.flo';
    g_mime_types('flv') := 'video/x-flv';
    g_mime_types('flw') := 'application/vnd.kde.kivio';
    g_mime_types('flx') := 'text/vnd.fmi.flexstor';
    g_mime_types('fly') := 'text/vnd.fly';
    g_mime_types('fm') := 'application/vnd.framemaker';
    g_mime_types('fnc') := 'application/vnd.frogans.fnc';
    g_mime_types('for') := 'text/x-fortran';
    g_mime_types('fpx') := 'image/vnd.fpx';
    g_mime_types('frame') := 'application/vnd.framemaker';
    g_mime_types('fsc') := 'application/vnd.fsc.weblaunch';
    g_mime_types('fst') := 'image/vnd.fst';
    g_mime_types('ftc') := 'application/vnd.fluxtime.clip';
    g_mime_types('fti') := 'application/vnd.anser-web-funds-transfer-initiation';
    g_mime_types('fvt') := 'video/vnd.fvt';
    g_mime_types('fxp') := 'application/vnd.adobe.fxp';
    g_mime_types('fxpl') := 'application/vnd.adobe.fxp';
    g_mime_types('fzs') := 'application/vnd.fuzzysheet';
    g_mime_types('g2w') := 'application/vnd.geoplan';
    g_mime_types('g3') := 'image/g3fax';
    g_mime_types('g3w') := 'application/vnd.geospace';
    g_mime_types('gac') := 'application/vnd.groove-account';
    g_mime_types('gam') := 'application/x-tads';
    g_mime_types('gbr') := 'application/rpki-ghostbusters';
    g_mime_types('gca') := 'application/x-gca-compressed';
    g_mime_types('gdl') := 'model/vnd.gdl';
    g_mime_types('geo') := 'application/vnd.dynageo';
    g_mime_types('gex') := 'application/vnd.geometry-explorer';
    g_mime_types('ggb') := 'application/vnd.geogebra.file';
    g_mime_types('ggt') := 'application/vnd.geogebra.tool';
    g_mime_types('ghf') := 'application/vnd.groove-help';
    g_mime_types('gif') := 'image/gif';
    g_mime_types('gim') := 'application/vnd.groove-identity-message';
    g_mime_types('gml') := 'application/gml+xml';
    g_mime_types('gmx') := 'application/vnd.gmx';
    g_mime_types('gnumeric') := 'application/x-gnumeric';
    g_mime_types('gph') := 'application/vnd.flographit';
    g_mime_types('gpx') := 'application/gpx+xml';
    g_mime_types('gqf') := 'application/vnd.grafeq';
    g_mime_types('gqs') := 'application/vnd.grafeq';
    g_mime_types('gram') := 'application/srgs';
    g_mime_types('gramps') := 'application/x-gramps-xml';
    g_mime_types('gre') := 'application/vnd.geometry-explorer';
    g_mime_types('grv') := 'application/vnd.groove-injector';
    g_mime_types('grxml') := 'application/srgs+xml';
    g_mime_types('gsf') := 'application/x-font-ghostscript';
    g_mime_types('gtar') := 'application/x-gtar';
    g_mime_types('gtm') := 'application/vnd.groove-tool-message';
    g_mime_types('gtw') := 'model/vnd.gtw';
    g_mime_types('gv') := 'text/vnd.graphviz';
    g_mime_types('gxf') := 'application/gxf';
    g_mime_types('gxt') := 'application/vnd.geonext';
    g_mime_types('h') := 'text/x-c';
    g_mime_types('h261') := 'video/h261';
    g_mime_types('h263') := 'video/h263';
    g_mime_types('h264') := 'video/h264';
    g_mime_types('hal') := 'application/vnd.hal+xml';
    g_mime_types('hbci') := 'application/vnd.hbci';
    g_mime_types('hdf') := 'application/x-hdf';
    g_mime_types('hh') := 'text/x-c';
    g_mime_types('hlp') := 'application/winhlp';
    g_mime_types('hpgl') := 'application/vnd.hp-hpgl';
    g_mime_types('hpid') := 'application/vnd.hp-hpid';
    g_mime_types('hps') := 'application/vnd.hp-hps';
    g_mime_types('hqx') := 'application/mac-binhex40';
    g_mime_types('htke') := 'application/vnd.kenameaapp';
    g_mime_types('htm') := 'text/html';
    g_mime_types('html') := 'text/html';
    g_mime_types('hvd') := 'application/vnd.yamaha.hv-dic';
    g_mime_types('hvp') := 'application/vnd.yamaha.hv-voice';
    g_mime_types('hvs') := 'application/vnd.yamaha.hv-script';
    g_mime_types('i2g') := 'application/vnd.intergeo';
    g_mime_types('icc') := 'application/vnd.iccprofile';
    g_mime_types('ice') := 'x-conference/x-cooltalk';
    g_mime_types('icm') := 'application/vnd.iccprofile';
    g_mime_types('ico') := 'image/x-icon';
    g_mime_types('ics') := 'text/calendar';
    g_mime_types('ief') := 'image/ief';
    g_mime_types('ifb') := 'text/calendar';
    g_mime_types('ifm') := 'application/vnd.shana.informed.formdata';
    g_mime_types('iges') := 'model/iges';
    g_mime_types('igl') := 'application/vnd.igloader';
    g_mime_types('igm') := 'application/vnd.insors.igm';
    g_mime_types('igs') := 'model/iges';
    g_mime_types('igx') := 'application/vnd.micrografx.igx';
    g_mime_types('iif') := 'application/vnd.shana.informed.interchange';
    g_mime_types('imp') := 'application/vnd.accpac.simply.imp';
    g_mime_types('ims') := 'application/vnd.ms-ims';
    g_mime_types('in') := 'text/plain';
    g_mime_types('ink') := 'application/inkml+xml';
    g_mime_types('inkml') := 'application/inkml+xml';
    g_mime_types('install') := 'application/x-install-instructions';
    g_mime_types('iota') := 'application/vnd.astraea-software.iota';
    g_mime_types('ipfix') := 'application/ipfix';
    g_mime_types('ipk') := 'application/vnd.shana.informed.package';
    g_mime_types('irm') := 'application/vnd.ibm.rights-management';
    g_mime_types('irp') := 'application/vnd.irepository.package+xml';
    g_mime_types('iso') := 'application/x-iso9660-image';
    g_mime_types('itp') := 'application/vnd.shana.informed.formtemplate';
    g_mime_types('ivp') := 'application/vnd.immervision-ivp';
    g_mime_types('ivu') := 'application/vnd.immervision-ivu';
    g_mime_types('jad') := 'text/vnd.sun.j2me.app-descriptor';
    g_mime_types('jam') := 'application/vnd.jam';
    g_mime_types('jar') := 'application/java-archive';
    g_mime_types('java') := 'text/x-java-source';
    g_mime_types('jisp') := 'application/vnd.jisp';
    g_mime_types('jlt') := 'application/vnd.hp-jlyt';
    g_mime_types('jnlp') := 'application/x-java-jnlp-file';
    g_mime_types('joda') := 'application/vnd.joost.joda-archive';
    g_mime_types('jpe') := 'image/jpeg';
    g_mime_types('jpeg') := 'image/jpeg';
    g_mime_types('jpg') := 'image/jpeg';
    g_mime_types('jpgm') := 'video/jpm';
    g_mime_types('jpgv') := 'video/jpeg';
    g_mime_types('jpm') := 'video/jpm';
    g_mime_types('js') := 'application/javascript';
    g_mime_types('json') := 'application/json';
    g_mime_types('jsonml') := 'application/jsonml+json';
    g_mime_types('kar') := 'audio/midi';
    g_mime_types('karbon') := 'application/vnd.kde.karbon';
    g_mime_types('kfo') := 'application/vnd.kde.kformula';
    g_mime_types('kia') := 'application/vnd.kidspiration';
    g_mime_types('kml') := 'application/vnd.google-earth.kml+xml';
    g_mime_types('kmz') := 'application/vnd.google-earth.kmz';
    g_mime_types('kne') := 'application/vnd.kinar';
    g_mime_types('knp') := 'application/vnd.kinar';
    g_mime_types('kon') := 'application/vnd.kde.kontour';
    g_mime_types('kpr') := 'application/vnd.kde.kpresenter';
    g_mime_types('kpt') := 'application/vnd.kde.kpresenter';
    g_mime_types('kpxx') := 'application/vnd.ds-keypoint';
    g_mime_types('ksp') := 'application/vnd.kde.kspread';
    g_mime_types('ktr') := 'application/vnd.kahootz';
    g_mime_types('ktx') := 'image/ktx';
    g_mime_types('ktz') := 'application/vnd.kahootz';
    g_mime_types('kwd') := 'application/vnd.kde.kword';
    g_mime_types('kwt') := 'application/vnd.kde.kword';
    g_mime_types('lasxml') := 'application/vnd.las.las+xml';
    g_mime_types('latex') := 'application/x-latex';
    g_mime_types('lbd') := 'application/vnd.llamagraphics.life-balance.desktop';
    g_mime_types('lbe') := 'application/vnd.llamagraphics.life-balance.exchange+xml';
    g_mime_types('les') := 'application/vnd.hhe.lesson-player';
    g_mime_types('lha') := 'application/x-lzh-compressed';
    g_mime_types('link66') := 'application/vnd.route66.link66+xml';
    g_mime_types('list') := 'text/plain';
    g_mime_types('list3820') := 'application/vnd.ibm.modcap';
    g_mime_types('listafp') := 'application/vnd.ibm.modcap';
    g_mime_types('lnk') := 'application/x-ms-shortcut';
    g_mime_types('log') := 'text/plain';
    g_mime_types('lostxml') := 'application/lost+xml';
    g_mime_types('lrf') := 'application/octet-stream';
    g_mime_types('lrm') := 'application/vnd.ms-lrm';
    g_mime_types('ltf') := 'application/vnd.frogans.ltf';
    g_mime_types('lvp') := 'audio/vnd.lucent.voice';
    g_mime_types('lwp') := 'application/vnd.lotus-wordpro';
    g_mime_types('lzh') := 'application/x-lzh-compressed';]'
||q'[
    g_mime_types('m13') := 'application/x-msmediaview';
    g_mime_types('m14') := 'application/x-msmediaview';
    g_mime_types('m1v') := 'video/mpeg';
    g_mime_types('m21') := 'application/mp21';
    g_mime_types('m2a') := 'audio/mpeg';
    g_mime_types('m2v') := 'video/mpeg';
    g_mime_types('m3a') := 'audio/mpeg';
    g_mime_types('m3u') := 'audio/x-mpegurl';
    g_mime_types('m3u8') := 'application/vnd.apple.mpegurl';
    g_mime_types('m4a') := 'audio/mp4';
    g_mime_types('m4u') := 'video/vnd.mpegurl';
    g_mime_types('m4v') := 'video/x-m4v';
    g_mime_types('ma') := 'application/mathematica';
    g_mime_types('mads') := 'application/mads+xml';
    g_mime_types('mag') := 'application/vnd.ecowin.chart';
    g_mime_types('maker') := 'application/vnd.framemaker';
    g_mime_types('man') := 'text/troff';
    g_mime_types('mar') := 'application/octet-stream';
    g_mime_types('mathml') := 'application/mathml+xml';
    g_mime_types('mb') := 'application/mathematica';
    g_mime_types('mbk') := 'application/vnd.mobius.mbk';
    g_mime_types('mbox') := 'application/mbox';
    g_mime_types('mc1') := 'application/vnd.medcalcdata';
    g_mime_types('mcd') := 'application/vnd.mcd';
    g_mime_types('mcurl') := 'text/vnd.curl.mcurl';
    g_mime_types('mdb') := 'application/x-msaccess';
    g_mime_types('mdi') := 'image/vnd.ms-modi';
    g_mime_types('me') := 'text/troff';
    g_mime_types('mesh') := 'model/mesh';
    g_mime_types('meta4') := 'application/metalink4+xml';
    g_mime_types('metalink') := 'application/metalink+xml';
    g_mime_types('mets') := 'application/mets+xml';
    g_mime_types('mfm') := 'application/vnd.mfmp';
    g_mime_types('mft') := 'application/rpki-manifest';
    g_mime_types('mgp') := 'application/vnd.osgeo.mapguide.package';
    g_mime_types('mgz') := 'application/vnd.proteus.magazine';
    g_mime_types('mid') := 'audio/midi';
    g_mime_types('midi') := 'audio/midi';
    g_mime_types('mie') := 'application/x-mie';
    g_mime_types('mif') := 'application/vnd.mif';
    g_mime_types('mime') := 'message/rfc822';
    g_mime_types('mj2') := 'video/mj2';
    g_mime_types('mjp2') := 'video/mj2';
    g_mime_types('mk3d') := 'video/x-matroska';
    g_mime_types('mka') := 'audio/x-matroska';
    g_mime_types('mks') := 'video/x-matroska';
    g_mime_types('mkv') := 'video/x-matroska';
    g_mime_types('mlp') := 'application/vnd.dolby.mlp';
    g_mime_types('mmd') := 'application/vnd.chipnuts.karaoke-mmd';
    g_mime_types('mmf') := 'application/vnd.smaf';
    g_mime_types('mmr') := 'image/vnd.fujixerox.edmics-mmr';
    g_mime_types('mng') := 'video/x-mng';
    g_mime_types('mny') := 'application/x-msmoney';
    g_mime_types('mobi') := 'application/x-mobipocket-ebook';
    g_mime_types('mods') := 'application/mods+xml';
    g_mime_types('mov') := 'video/quicktime';
    g_mime_types('movie') := 'video/x-sgi-movie';
    g_mime_types('mp2') := 'audio/mpeg';
    g_mime_types('mp21') := 'application/mp21';
    g_mime_types('mp2a') := 'audio/mpeg';
    g_mime_types('mp3') := 'audio/mpeg';
    g_mime_types('mp4') := 'video/mp4';
    g_mime_types('mp4a') := 'audio/mp4';
    g_mime_types('mp4s') := 'application/mp4';
    g_mime_types('mp4v') := 'video/mp4';
    g_mime_types('mpc') := 'application/vnd.mophun.certificate';
    g_mime_types('mpe') := 'video/mpeg';
    g_mime_types('mpeg') := 'video/mpeg';
    g_mime_types('mpg') := 'video/mpeg';
    g_mime_types('mpg4') := 'video/mp4';
    g_mime_types('mpga') := 'audio/mpeg';
    g_mime_types('mpkg') := 'application/vnd.apple.installer+xml';
    g_mime_types('mpm') := 'application/vnd.blueice.multipass';
    g_mime_types('mpn') := 'application/vnd.mophun.application';
    g_mime_types('mpp') := 'application/vnd.ms-project';
    g_mime_types('mpt') := 'application/vnd.ms-project';
    g_mime_types('mpy') := 'application/vnd.ibm.minipay';
    g_mime_types('mqy') := 'application/vnd.mobius.mqy';
    g_mime_types('mrc') := 'application/marc';
    g_mime_types('mrcx') := 'application/marcxml+xml';
    g_mime_types('ms') := 'text/troff';
    g_mime_types('mscml') := 'application/mediaservercontrol+xml';
    g_mime_types('mseed') := 'application/vnd.fdsn.mseed';
    g_mime_types('mseq') := 'application/vnd.mseq';
    g_mime_types('msf') := 'application/vnd.epson.msf';
    g_mime_types('msh') := 'model/mesh';
    g_mime_types('msi') := 'application/x-msdownload';
    g_mime_types('msl') := 'application/vnd.mobius.msl';
    g_mime_types('msty') := 'application/vnd.muvee.style';
    g_mime_types('mts') := 'model/vnd.mts';
    g_mime_types('mus') := 'application/vnd.musician';
    g_mime_types('musicxml') := 'application/vnd.recordare.musicxml+xml';
    g_mime_types('mvb') := 'application/x-msmediaview';
    g_mime_types('mwf') := 'application/vnd.mfer';
    g_mime_types('mxf') := 'application/mxf';
    g_mime_types('mxl') := 'application/vnd.recordare.musicxml';
    g_mime_types('mxml') := 'application/xv+xml';
    g_mime_types('mxs') := 'application/vnd.triscape.mxs';
    g_mime_types('mxu') := 'video/vnd.mpegurl';
    g_mime_types('n-gage') := 'application/vnd.nokia.n-gage.symbian.install';
    g_mime_types('n3') := 'text/n3';
    g_mime_types('nb') := 'application/mathematica';
    g_mime_types('nbp') := 'application/vnd.wolfram.player';
    g_mime_types('nc') := 'application/x-netcdf';
    g_mime_types('ncx') := 'application/x-dtbncx+xml';
    g_mime_types('nfo') := 'text/x-nfo';
    g_mime_types('ngdat') := 'application/vnd.nokia.n-gage.data';
    g_mime_types('nitf') := 'application/vnd.nitf';
    g_mime_types('nlu') := 'application/vnd.neurolanguage.nlu';
    g_mime_types('nml') := 'application/vnd.enliven';
    g_mime_types('nnd') := 'application/vnd.noblenet-directory';
    g_mime_types('nns') := 'application/vnd.noblenet-sealer';
    g_mime_types('nnw') := 'application/vnd.noblenet-web';
    g_mime_types('npx') := 'image/vnd.net-fpx';
    g_mime_types('nsc') := 'application/x-conference';
    g_mime_types('nsf') := 'application/vnd.lotus-notes';
    g_mime_types('ntf') := 'application/vnd.nitf';
    g_mime_types('nzb') := 'application/x-nzb';
    g_mime_types('oa2') := 'application/vnd.fujitsu.oasys2';
    g_mime_types('oa3') := 'application/vnd.fujitsu.oasys3';
    g_mime_types('oas') := 'application/vnd.fujitsu.oasys';
    g_mime_types('obd') := 'application/x-msbinder';
    g_mime_types('obj') := 'application/x-tgif';
    g_mime_types('oda') := 'application/oda';
    g_mime_types('odb') := 'application/vnd.oasis.opendocument.database';
    g_mime_types('odc') := 'application/vnd.oasis.opendocument.chart';
    g_mime_types('odf') := 'application/vnd.oasis.opendocument.formula';
    g_mime_types('odft') := 'application/vnd.oasis.opendocument.formula-template';
    g_mime_types('odg') := 'application/vnd.oasis.opendocument.graphics';
    g_mime_types('odi') := 'application/vnd.oasis.opendocument.image';
    g_mime_types('odm') := 'application/vnd.oasis.opendocument.text-master';
    g_mime_types('odp') := 'application/vnd.oasis.opendocument.presentation';
    g_mime_types('ods') := 'application/vnd.oasis.opendocument.spreadsheet';
    g_mime_types('odt') := 'application/vnd.oasis.opendocument.text';
    g_mime_types('oga') := 'audio/ogg';
    g_mime_types('ogg') := 'audio/ogg';
    g_mime_types('ogv') := 'video/ogg';
    g_mime_types('ogx') := 'application/ogg';
    g_mime_types('omdoc') := 'application/omdoc+xml';
    g_mime_types('onepkg') := 'application/onenote';
    g_mime_types('onetmp') := 'application/onenote';
    g_mime_types('onetoc') := 'application/onenote';
    g_mime_types('onetoc2') := 'application/onenote';
    g_mime_types('opf') := 'application/oebps-package+xml';
    g_mime_types('opml') := 'text/x-opml';
    g_mime_types('oprc') := 'application/vnd.palm';
    g_mime_types('opus') := 'audio/ogg';
    g_mime_types('org') := 'application/vnd.lotus-organizer';
    g_mime_types('osf') := 'application/vnd.yamaha.openscoreformat';
    g_mime_types('osfpvg') := 'application/vnd.yamaha.openscoreformat.osfpvg+xml';
    g_mime_types('otc') := 'application/vnd.oasis.opendocument.chart-template';
    g_mime_types('otf') := 'font/otf';
    g_mime_types('otg') := 'application/vnd.oasis.opendocument.graphics-template';
    g_mime_types('oth') := 'application/vnd.oasis.opendocument.text-web';
    g_mime_types('oti') := 'application/vnd.oasis.opendocument.image-template';
    g_mime_types('otp') := 'application/vnd.oasis.opendocument.presentation-template';
    g_mime_types('ots') := 'application/vnd.oasis.opendocument.spreadsheet-template';
    g_mime_types('ott') := 'application/vnd.oasis.opendocument.text-template';
    g_mime_types('oxps') := 'application/oxps';
    g_mime_types('oxt') := 'application/vnd.openofficeorg.extension';
    g_mime_types('p') := 'text/x-pascal';
    g_mime_types('p10') := 'application/pkcs10';
    g_mime_types('p12') := 'application/x-pkcs12';
    g_mime_types('p7b') := 'application/x-pkcs7-certificates';
    g_mime_types('p7c') := 'application/pkcs7-mime';
    g_mime_types('p7m') := 'application/pkcs7-mime';
    g_mime_types('p7r') := 'application/x-pkcs7-certreqresp';
    g_mime_types('p7s') := 'application/pkcs7-signature';
    g_mime_types('p8') := 'application/pkcs8';
    g_mime_types('pas') := 'text/x-pascal';
    g_mime_types('paw') := 'application/vnd.pawaafile';
    g_mime_types('pbd') := 'application/vnd.powerbuilder6';
    g_mime_types('pbm') := 'image/x-portable-bitmap';
    g_mime_types('pcap') := 'application/vnd.tcpdump.pcap';
    g_mime_types('pcf') := 'application/x-font-pcf';
    g_mime_types('pcl') := 'application/vnd.hp-pcl';
    g_mime_types('pclxl') := 'application/vnd.hp-pclxl';
    g_mime_types('pct') := 'image/x-pict';
    g_mime_types('pcurl') := 'application/vnd.curl.pcurl';
    g_mime_types('pcx') := 'image/x-pcx';
    g_mime_types('pdb') := 'application/vnd.palm';
    g_mime_types('pdf') := 'application/pdf';
    g_mime_types('pfa') := 'application/x-font-type1';
    g_mime_types('pfb') := 'application/x-font-type1';
    g_mime_types('pfm') := 'application/x-font-type1';
    g_mime_types('pfr') := 'application/font-tdpfr';
    g_mime_types('pfx') := 'application/x-pkcs12';
    g_mime_types('pgm') := 'image/x-portable-graymap';
    g_mime_types('pgn') := 'application/x-chess-pgn';
    g_mime_types('pgp') := 'application/pgp-encrypted';
    g_mime_types('pic') := 'image/x-pict';
    g_mime_types('pkg') := 'application/octet-stream';
    g_mime_types('pki') := 'application/pkixcmp';
    g_mime_types('pkipath') := 'application/pkix-pkipath';
    g_mime_types('plb') := 'application/vnd.3gpp.pic-bw-large';
    g_mime_types('plc') := 'application/vnd.mobius.plc';
    g_mime_types('plf') := 'application/vnd.pocketlearn';
    g_mime_types('pls') := 'application/pls+xml';
    g_mime_types('pml') := 'application/vnd.ctc-posml';
    g_mime_types('png') := 'image/png';
    g_mime_types('pnm') := 'image/x-portable-anymap';
    g_mime_types('portpkg') := 'application/vnd.macports.portpkg';
    g_mime_types('pot') := 'application/vnd.ms-powerpoint';
    g_mime_types('potm') := 'application/vnd.ms-powerpoint.template.macroenabled.12';
    g_mime_types('potx') := 'application/vnd.openxmlformats-officedocument.presentationml.template';
    g_mime_types('ppam') := 'application/vnd.ms-powerpoint.addin.macroenabled.12';
    g_mime_types('ppd') := 'application/vnd.cups-ppd';
    g_mime_types('ppm') := 'image/x-portable-pixmap';
    g_mime_types('pps') := 'application/vnd.ms-powerpoint';
    g_mime_types('ppsm') := 'application/vnd.ms-powerpoint.slideshow.macroenabled.12';
    g_mime_types('ppsx') := 'application/vnd.openxmlformats-officedocument.presentationml.slideshow';
    g_mime_types('ppt') := 'application/vnd.ms-powerpoint';
    g_mime_types('pptm') := 'application/vnd.ms-powerpoint.presentation.macroenabled.12';
    g_mime_types('pptx') := 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    g_mime_types('pqa') := 'application/vnd.palm';
    g_mime_types('prc') := 'application/x-mobipocket-ebook';
    g_mime_types('pre') := 'application/vnd.lotus-freelance';
    g_mime_types('prf') := 'application/pics-rules';
    g_mime_types('ps') := 'application/postscript';
    g_mime_types('psb') := 'application/vnd.3gpp.pic-bw-small';
    g_mime_types('psd') := 'image/vnd.adobe.photoshop';
    g_mime_types('psf') := 'application/x-font-linux-psf';
    g_mime_types('pskcxml') := 'application/pskc+xml';
    g_mime_types('ptid') := 'application/vnd.pvi.ptid1';
    g_mime_types('pub') := 'application/x-mspublisher';
    g_mime_types('pvb') := 'application/vnd.3gpp.pic-bw-var';
    g_mime_types('pwn') := 'application/vnd.3m.post-it-notes';
    g_mime_types('pya') := 'audio/vnd.ms-playready.media.pya';
    g_mime_types('pyv') := 'video/vnd.ms-playready.media.pyv';
    g_mime_types('qam') := 'application/vnd.epson.quickanime';
    g_mime_types('qbo') := 'application/vnd.intu.qbo';
    g_mime_types('qfx') := 'application/vnd.intu.qfx';
    g_mime_types('qps') := 'application/vnd.publishare-delta-tree';
    g_mime_types('qt') := 'video/quicktime';
    g_mime_types('qwd') := 'application/vnd.quark.quarkxpress';
    g_mime_types('qwt') := 'application/vnd.quark.quarkxpress';
    g_mime_types('qxb') := 'application/vnd.quark.quarkxpress';
    g_mime_types('qxd') := 'application/vnd.quark.quarkxpress';
    g_mime_types('qxl') := 'application/vnd.quark.quarkxpress';
    g_mime_types('qxt') := 'application/vnd.quark.quarkxpress';
    g_mime_types('ra') := 'audio/x-pn-realaudio';
    g_mime_types('ram') := 'audio/x-pn-realaudio';
    g_mime_types('rar') := 'application/x-rar-compressed';
    g_mime_types('ras') := 'image/x-cmu-raster';
    g_mime_types('rcprofile') := 'application/vnd.ipunplugged.rcprofile';
    g_mime_types('rdf') := 'application/rdf+xml';
    g_mime_types('rdz') := 'application/vnd.data-vision.rdz';
    g_mime_types('rep') := 'application/vnd.businessobjects';
    g_mime_types('res') := 'application/x-dtbresource+xml';
    g_mime_types('rgb') := 'image/x-rgb';
    g_mime_types('rif') := 'application/reginfo+xml';
    g_mime_types('rip') := 'audio/vnd.rip';
    g_mime_types('ris') := 'application/x-research-info-systems';
    g_mime_types('rl') := 'application/resource-lists+xml';
    g_mime_types('rlc') := 'image/vnd.fujixerox.edmics-rlc';
    g_mime_types('rld') := 'application/resource-lists-diff+xml';
    g_mime_types('rm') := 'application/vnd.rn-realmedia';
    g_mime_types('rmi') := 'audio/midi';
    g_mime_types('rmp') := 'audio/x-pn-realaudio-plugin';
    g_mime_types('rms') := 'application/vnd.jcp.javame.midlet-rms';
    g_mime_types('rmvb') := 'application/vnd.rn-realmedia-vbr';
    g_mime_types('rnc') := 'application/relax-ng-compact-syntax';
    g_mime_types('roa') := 'application/rpki-roa';
    g_mime_types('roff') := 'text/troff';
    g_mime_types('rp9') := 'application/vnd.cloanto.rp9';
    g_mime_types('rpss') := 'application/vnd.nokia.radio-presets';
    g_mime_types('rpst') := 'application/vnd.nokia.radio-preset';
    g_mime_types('rq') := 'application/sparql-query';
    g_mime_types('rs') := 'application/rls-services+xml';
    g_mime_types('rsd') := 'application/rsd+xml';
    g_mime_types('rss') := 'application/rss+xml';
    g_mime_types('rtf') := 'application/rtf';
    g_mime_types('rtx') := 'text/richtext';
    g_mime_types('s') := 'text/x-asm';
    g_mime_types('s3m') := 'audio/s3m';
    g_mime_types('saf') := 'application/vnd.yamaha.smaf-audio';
    g_mime_types('sbml') := 'application/sbml+xml';
    g_mime_types('sc') := 'application/vnd.ibm.secure-container';
    g_mime_types('scd') := 'application/x-msschedule';
    g_mime_types('scm') := 'application/vnd.lotus-screencam';
    g_mime_types('scq') := 'application/scvp-cv-request';
    g_mime_types('scs') := 'application/scvp-cv-response';
    g_mime_types('scurl') := 'text/vnd.curl.scurl';
    g_mime_types('sda') := 'application/vnd.stardivision.draw';
    g_mime_types('sdc') := 'application/vnd.stardivision.calc';
    g_mime_types('sdd') := 'application/vnd.stardivision.impress';
    g_mime_types('sdkd') := 'application/vnd.solent.sdkm+xml';
    g_mime_types('sdkm') := 'application/vnd.solent.sdkm+xml';
    g_mime_types('sdp') := 'application/sdp';
    g_mime_types('sdw') := 'application/vnd.stardivision.writer';
    g_mime_types('see') := 'application/vnd.seemail';
    g_mime_types('seed') := 'application/vnd.fdsn.seed';
    g_mime_types('sema') := 'application/vnd.sema';
    g_mime_types('semd') := 'application/vnd.semd';
    g_mime_types('semf') := 'application/vnd.semf';
    g_mime_types('ser') := 'application/java-serialized-object';
    g_mime_types('setpay') := 'application/set-payment-initiation';
    g_mime_types('setreg') := 'application/set-registration-initiation';
    g_mime_types('sfd-hdstx') := 'application/vnd.hydrostatix.sof-data';
    g_mime_types('sfs') := 'application/vnd.spotfire.sfs';
    g_mime_types('sfv') := 'text/x-sfv';
    g_mime_types('sgi') := 'image/sgi';
    g_mime_types('sgl') := 'application/vnd.stardivision.writer-global';
    g_mime_types('sgm') := 'text/sgml';
    g_mime_types('sgml') := 'text/sgml';
    g_mime_types('sh') := 'application/x-sh';
    g_mime_types('shar') := 'application/x-shar';
    g_mime_types('shf') := 'application/shf+xml';
    g_mime_types('sid') := 'image/x-mrsid-image';
    g_mime_types('sig') := 'application/pgp-signature';
    g_mime_types('sil') := 'audio/silk';
    g_mime_types('silo') := 'model/mesh';
    g_mime_types('sis') := 'application/vnd.symbian.install';
    g_mime_types('sisx') := 'application/vnd.symbian.install';
    g_mime_types('sit') := 'application/x-stuffit';
    g_mime_types('sitx') := 'application/x-stuffitx';
    g_mime_types('skd') := 'application/vnd.koan';
    g_mime_types('skm') := 'application/vnd.koan';
    g_mime_types('skp') := 'application/vnd.koan';
    g_mime_types('skt') := 'application/vnd.koan';
    g_mime_types('sldm') := 'application/vnd.ms-powerpoint.slide.macroenabled.12';
    g_mime_types('sldx') := 'application/vnd.openxmlformats-officedocument.presentationml.slide';
    g_mime_types('slt') := 'application/vnd.epson.salt';
    g_mime_types('sm') := 'application/vnd.stepmania.stepchart';
    g_mime_types('smf') := 'application/vnd.stardivision.math';
    g_mime_types('smi') := 'application/smil+xml';
    g_mime_types('smil') := 'application/smil+xml';
    g_mime_types('smv') := 'video/x-smv';
    g_mime_types('smzip') := 'application/vnd.stepmania.package';
    g_mime_types('snd') := 'audio/basic';
    g_mime_types('snf') := 'application/x-font-snf';
    g_mime_types('so') := 'application/octet-stream';
    g_mime_types('spc') := 'application/x-pkcs7-certificates';
    g_mime_types('spf') := 'application/vnd.yamaha.smaf-phrase';
    g_mime_types('spl') := 'application/x-futuresplash';
    g_mime_types('spot') := 'text/vnd.in3d.spot';
    g_mime_types('spp') := 'application/scvp-vp-response';
    g_mime_types('spq') := 'application/scvp-vp-request';
    g_mime_types('spx') := 'audio/ogg';
    g_mime_types('sql') := 'application/x-sql';
    g_mime_types('src') := 'application/x-wais-source';
    g_mime_types('srt') := 'application/x-subrip';
    g_mime_types('sru') := 'application/sru+xml';
    g_mime_types('srx') := 'application/sparql-results+xml';
    g_mime_types('ssdl') := 'application/ssdl+xml';
    g_mime_types('sse') := 'application/vnd.kodak-descriptor';
    g_mime_types('ssf') := 'application/vnd.epson.ssf';
    g_mime_types('ssml') := 'application/ssml+xml';
    g_mime_types('st') := 'application/vnd.sailingtracker.track';
    g_mime_types('stc') := 'application/vnd.sun.xml.calc.template';
    g_mime_types('std') := 'application/vnd.sun.xml.draw.template';
    g_mime_types('stf') := 'application/vnd.wt.stf';
    g_mime_types('sti') := 'application/vnd.sun.xml.impress.template';
    g_mime_types('stk') := 'application/hyperstudio';
    g_mime_types('stl') := 'application/vnd.ms-pki.stl';
    g_mime_types('str') := 'application/vnd.pg.format';
    g_mime_types('stw') := 'application/vnd.sun.xml.writer.template';
    g_mime_types('sub') := 'image/vnd.dvb.subtitle';
    g_mime_types('sub') := 'text/vnd.dvb.subtitle';
    g_mime_types('sus') := 'application/vnd.sus-calendar';
    g_mime_types('susp') := 'application/vnd.sus-calendar';
    g_mime_types('sv4cpio') := 'application/x-sv4cpio';
    g_mime_types('sv4crc') := 'application/x-sv4crc';
    g_mime_types('svc') := 'application/vnd.dvb.service';
    g_mime_types('svd') := 'application/vnd.svd';
    g_mime_types('svg') := 'image/svg+xml';
    g_mime_types('svgz') := 'image/svg+xml';
    g_mime_types('swa') := 'application/x-director';
    g_mime_types('swf') := 'application/x-shockwave-flash';
    g_mime_types('swi') := 'application/vnd.aristanetworks.swi';
    g_mime_types('sxc') := 'application/vnd.sun.xml.calc';
    g_mime_types('sxd') := 'application/vnd.sun.xml.draw';
    g_mime_types('sxg') := 'application/vnd.sun.xml.writer.global';
    g_mime_types('sxi') := 'application/vnd.sun.xml.impress';
    g_mime_types('sxm') := 'application/vnd.sun.xml.math';
    g_mime_types('sxw') := 'application/vnd.sun.xml.writer';
    g_mime_types('t') := 'text/troff';
    g_mime_types('t3') := 'application/x-t3vm-image';
    g_mime_types('taglet') := 'application/vnd.mynfc';
    g_mime_types('tao') := 'application/vnd.tao.intent-module-archive';
    g_mime_types('tar') := 'application/x-tar';
    g_mime_types('tcap') := 'application/vnd.3gpp2.tcap';
    g_mime_types('tcl') := 'application/x-tcl';
    g_mime_types('teacher') := 'application/vnd.smart.teacher';
    g_mime_types('tei') := 'application/tei+xml';
    g_mime_types('teicorpus') := 'application/tei+xml';
    g_mime_types('tex') := 'application/x-tex';
    g_mime_types('texi') := 'application/x-texinfo';
    g_mime_types('texinfo') := 'application/x-texinfo';
    g_mime_types('text') := 'text/plain';
    g_mime_types('tfi') := 'application/thraud+xml';
    g_mime_types('tfm') := 'application/x-tex-tfm';
    g_mime_types('tga') := 'image/x-tga';
    g_mime_types('thmx') := 'application/vnd.ms-officetheme';
    g_mime_types('tif') := 'image/tiff';
    g_mime_types('tiff') := 'image/tiff';
    g_mime_types('tmo') := 'application/vnd.tmobile-livetv';
    g_mime_types('torrent') := 'application/x-bittorrent';
    g_mime_types('tpl') := 'application/vnd.groove-tool-template';
    g_mime_types('tpt') := 'application/vnd.trid.tpt';
    g_mime_types('tr') := 'text/troff';
    g_mime_types('tra') := 'application/vnd.trueapp';
    g_mime_types('trm') := 'application/x-msterminal';
    g_mime_types('tsd') := 'application/timestamped-data';
    g_mime_types('tsv') := 'text/tab-separated-values';
    g_mime_types('ttc') := 'font/collection';
    g_mime_types('ttf') := 'font/ttf';
    g_mime_types('ttl') := 'text/turtle';
    g_mime_types('twd') := 'application/vnd.simtech-mindmapper';
    g_mime_types('twds') := 'application/vnd.simtech-mindmapper';
    g_mime_types('txd') := 'application/vnd.genomatix.tuxedo';
    g_mime_types('txf') := 'application/vnd.mobius.txf';
    g_mime_types('txt') := 'text/plain';
    g_mime_types('u32') := 'application/x-authorware-bin';
    g_mime_types('udeb') := 'application/x-debian-package';
    g_mime_types('ufd') := 'application/vnd.ufdl';
    g_mime_types('ufdl') := 'application/vnd.ufdl';
    g_mime_types('ulx') := 'application/x-glulx';
    g_mime_types('umj') := 'application/vnd.umajin';
    g_mime_types('unityweb') := 'application/vnd.unity';
    g_mime_types('uoml') := 'application/vnd.uoml+xml';
    g_mime_types('uri') := 'text/uri-list';
    g_mime_types('uris') := 'text/uri-list';
    g_mime_types('urls') := 'text/uri-list';
    g_mime_types('ustar') := 'application/x-ustar';
    g_mime_types('utz') := 'application/vnd.uiq.theme';
    g_mime_types('uu') := 'text/x-uuencode';
    g_mime_types('uva') := 'audio/vnd.dece.audio';
    g_mime_types('uvd') := 'application/vnd.dece.data';
    g_mime_types('uvf') := 'application/vnd.dece.data';
    g_mime_types('uvg') := 'image/vnd.dece.graphic';
    g_mime_types('uvh') := 'video/vnd.dece.hd';
    g_mime_types('uvi') := 'image/vnd.dece.graphic';
    g_mime_types('uvm') := 'video/vnd.dece.mobile';
    g_mime_types('uvp') := 'video/vnd.dece.pd';
    g_mime_types('uvs') := 'video/vnd.dece.sd';
    g_mime_types('uvt') := 'application/vnd.dece.ttml+xml';
    g_mime_types('uvu') := 'video/vnd.uvvu.mp4';
    g_mime_types('uvv') := 'video/vnd.dece.video';
    g_mime_types('uvva') := 'audio/vnd.dece.audio';
    g_mime_types('uvvd') := 'application/vnd.dece.data';
    g_mime_types('uvvf') := 'application/vnd.dece.data';
    g_mime_types('uvvg') := 'image/vnd.dece.graphic';
    g_mime_types('uvvh') := 'video/vnd.dece.hd';
    g_mime_types('uvvi') := 'image/vnd.dece.graphic';
    g_mime_types('uvvm') := 'video/vnd.dece.mobile';
    g_mime_types('uvvp') := 'video/vnd.dece.pd';
    g_mime_types('uvvs') := 'video/vnd.dece.sd';
    g_mime_types('uvvt') := 'application/vnd.dece.ttml+xml';
    g_mime_types('uvvu') := 'video/vnd.uvvu.mp4';
    g_mime_types('uvvv') := 'video/vnd.dece.video';
    g_mime_types('uvvx') := 'application/vnd.dece.unspecified';
    g_mime_types('uvvz') := 'application/vnd.dece.zip';
    g_mime_types('uvx') := 'application/vnd.dece.unspecified';
    g_mime_types('uvz') := 'application/vnd.dece.zip';
    g_mime_types('vcard') := 'text/vcard';
    g_mime_types('vcd') := 'application/x-cdlink';
    g_mime_types('vcf') := 'text/x-vcard';
    g_mime_types('vcg') := 'application/vnd.groove-vcard';
    g_mime_types('vcs') := 'text/x-vcalendar';
    g_mime_types('vcx') := 'application/vnd.vcx';
    g_mime_types('vis') := 'application/vnd.visionary';
    g_mime_types('viv') := 'video/vnd.vivo';
    g_mime_types('vob') := 'video/x-ms-vob';
    g_mime_types('vor') := 'application/vnd.stardivision.writer';
    g_mime_types('vox') := 'application/x-authorware-bin';
    g_mime_types('vrml') := 'model/vrml';
    g_mime_types('vsd') := 'application/vnd.visio';
    g_mime_types('vsf') := 'application/vnd.vsf';
    g_mime_types('vss') := 'application/vnd.visio';
    g_mime_types('vst') := 'application/vnd.visio';
    g_mime_types('vsw') := 'application/vnd.visio';
    g_mime_types('vtu') := 'model/vnd.vtu';
    g_mime_types('vxml') := 'application/voicexml+xml';
    g_mime_types('w3d') := 'application/x-director';
    g_mime_types('wad') := 'application/x-doom';
    g_mime_types('wav') := 'audio/x-wav';
    g_mime_types('wax') := 'audio/x-ms-wax';
    g_mime_types('wbmp') := 'image/vnd.wap.wbmp';
    g_mime_types('wbs') := 'application/vnd.criticaltools.wbs+xml';
    g_mime_types('wbxml') := 'application/vnd.wap.wbxml';
    g_mime_types('wcm') := 'application/vnd.ms-works';
    g_mime_types('wdb') := 'application/vnd.ms-works';
    g_mime_types('wdp') := 'image/vnd.ms-photo';
    g_mime_types('weba') := 'audio/webm';
    g_mime_types('webm') := 'video/webm';
    g_mime_types('webp') := 'image/webp';
    g_mime_types('wg') := 'application/vnd.pmi.widget';
    g_mime_types('wgt') := 'application/widget';
    g_mime_types('wks') := 'application/vnd.ms-works';
    g_mime_types('wm') := 'video/x-ms-wm';
    g_mime_types('wma') := 'audio/x-ms-wma';
    g_mime_types('wmd') := 'application/x-ms-wmd';
    g_mime_types('wmf') := 'application/x-msmetafile';
    g_mime_types('wml') := 'text/vnd.wap.wml';
    g_mime_types('wmlc') := 'application/vnd.wap.wmlc';
    g_mime_types('wmls') := 'text/vnd.wap.wmlscript';
    g_mime_types('wmlsc') := 'application/vnd.wap.wmlscriptc';
    g_mime_types('wmv') := 'video/x-ms-wmv';
    g_mime_types('wmx') := 'video/x-ms-wmx';
    g_mime_types('wmz') := 'application/x-ms-wmz';
    g_mime_types('wmz') := 'application/x-msmetafile';
    g_mime_types('woff') := 'font/woff';
    g_mime_types('woff2') := 'font/woff2';
    g_mime_types('wpd') := 'application/vnd.wordperfect';
    g_mime_types('wpl') := 'application/vnd.ms-wpl';
    g_mime_types('wps') := 'application/vnd.ms-works';
    g_mime_types('wqd') := 'application/vnd.wqd';
    g_mime_types('wri') := 'application/x-mswrite';
    g_mime_types('wrl') := 'model/vrml';
    g_mime_types('wsdl') := 'application/wsdl+xml';
    g_mime_types('wspolicy') := 'application/wspolicy+xml';
    g_mime_types('wtb') := 'application/vnd.webturbo';
    g_mime_types('wvx') := 'video/x-ms-wvx';
    g_mime_types('x32') := 'application/x-authorware-bin';
    g_mime_types('x3d') := 'model/x3d+xml';
    g_mime_types('x3db') := 'model/x3d+binary';
    g_mime_types('x3dbz') := 'model/x3d+binary';
    g_mime_types('x3dv') := 'model/x3d+vrml';
    g_mime_types('x3dvz') := 'model/x3d+vrml';
    g_mime_types('x3dz') := 'model/x3d+xml';
    g_mime_types('xaml') := 'application/xaml+xml';
    g_mime_types('xap') := 'application/x-silverlight-app';
    g_mime_types('xar') := 'application/vnd.xara';
    g_mime_types('xbap') := 'application/x-ms-xbap';
    g_mime_types('xbd') := 'application/vnd.fujixerox.docuworks.binder';
    g_mime_types('xbm') := 'image/x-xbitmap';
    g_mime_types('xdf') := 'application/xcap-diff+xml';
    g_mime_types('xdm') := 'application/vnd.syncml.dm+xml';
    g_mime_types('xdp') := 'application/vnd.adobe.xdp+xml';
    g_mime_types('xdssc') := 'application/dssc+xml';
    g_mime_types('xdw') := 'application/vnd.fujixerox.docuworks';
    g_mime_types('xenc') := 'application/xenc+xml';
    g_mime_types('xer') := 'application/patch-ops-error+xml';
    g_mime_types('xfdf') := 'application/vnd.adobe.xfdf';
    g_mime_types('xfdl') := 'application/vnd.xfdl';
    g_mime_types('xht') := 'application/xhtml+xml';
    g_mime_types('xhtml') := 'application/xhtml+xml';
    g_mime_types('xhvml') := 'application/xv+xml';
    g_mime_types('xif') := 'image/vnd.xiff';
    g_mime_types('xla') := 'application/vnd.ms-excel';
    g_mime_types('xlam') := 'application/vnd.ms-excel.addin.macroenabled.12';
    g_mime_types('xlc') := 'application/vnd.ms-excel';
    g_mime_types('xlf') := 'application/x-xliff+xml';
    g_mime_types('xlm') := 'application/vnd.ms-excel';
    g_mime_types('xls') := 'application/vnd.ms-excel';
    g_mime_types('xlsb') := 'application/vnd.ms-excel.sheet.binary.macroenabled.12';
    g_mime_types('xlsm') := 'application/vnd.ms-excel.sheet.macroenabled.12';
    g_mime_types('xlsx') := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    g_mime_types('xlt') := 'application/vnd.ms-excel';
    g_mime_types('xltm') := 'application/vnd.ms-excel.template.macroenabled.12';
    g_mime_types('xltx') := 'application/vnd.openxmlformats-officedocument.spreadsheetml.template';
    g_mime_types('xlw') := 'application/vnd.ms-excel';
    g_mime_types('xm') := 'audio/xm';
    g_mime_types('xml') := 'application/xml';
    g_mime_types('xo') := 'application/vnd.olpc-sugar';
    g_mime_types('xop') := 'application/xop+xml';
    g_mime_types('xpi') := 'application/x-xpinstall';
    g_mime_types('xpl') := 'application/xproc+xml';
    g_mime_types('xpm') := 'image/x-xpixmap';
    g_mime_types('xpr') := 'application/vnd.is-xpr';
    g_mime_types('xps') := 'application/vnd.ms-xpsdocument';
    g_mime_types('xpw') := 'application/vnd.intercon.formnet';
    g_mime_types('xpx') := 'application/vnd.intercon.formnet';
    g_mime_types('xsl') := 'application/xml';
    g_mime_types('xslt') := 'application/xslt+xml';
    g_mime_types('xsm') := 'application/vnd.syncml+xml';
    g_mime_types('xspf') := 'application/xspf+xml';
    g_mime_types('xul') := 'application/vnd.mozilla.xul+xml';
    g_mime_types('xvm') := 'application/xv+xml';
    g_mime_types('xvml') := 'application/xv+xml';
    g_mime_types('xwd') := 'image/x-xwindowdump';
    g_mime_types('xyz') := 'chemical/x-xyz';
    g_mime_types('xz') := 'application/x-xz';
    g_mime_types('yang') := 'application/yang';
    g_mime_types('yin') := 'application/yin+xml';
    g_mime_types('z1') := 'application/x-zmachine';
    g_mime_types('z2') := 'application/x-zmachine';
    g_mime_types('z3') := 'application/x-zmachine';
    g_mime_types('z4') := 'application/x-zmachine';
    g_mime_types('z5') := 'application/x-zmachine';
    g_mime_types('z6') := 'application/x-zmachine';
    g_mime_types('z7') := 'application/x-zmachine';
    g_mime_types('z8') := 'application/x-zmachine';
    g_mime_types('zaz') := 'application/vnd.zzazz.deck+xml';
    g_mime_types('zip') := 'application/zip';
    g_mime_types('zir') := 'application/vnd.zul';
    g_mime_types('zirz') := 'application/vnd.zul';
    g_mime_types('zmm') := 'application/vnd.handheld-entertainment+xml';
END mime_type;]';
$else
    dbms_output.put_line('$$use_mime_type was not true so did not deploy package mime_type');
$end
END;
/
CREATE OR REPLACE TYPE html_email_attachment_udt AS OBJECT (
         file_name      VARCHAR2(64)
        ,clob_content   CLOB            -- give either clob or blob, not both
        ,blob_content   BLOB
        ,mime_type      VARCHAR2(120)
);
/
show errors
CREATE OR REPLACE TYPE arr_html_email_attachment_udt AS TABLE OF html_email_attachment_udt;
/
show errors
--
-- oh my, how embarrasing for Oracle. You cannot use compile directives in the
-- definition of a user defined type object. You can use them just fine in the
-- body, but not in creating the type itself (type specification). We will use 
-- the compile directives to create a character string that we feed to execute
-- immediate. Such a damn hack. Shame Oracle! Shame!
-- At least the hack is only for deployment code. I can live with it.
--
BEGIN
EXECUTE IMMEDIATE q'[
CREATE OR REPLACE TYPE html_email_udt AS OBJECT (
    /*
        An object for creating and sending an email message with an HTML
        body and optional attachments.
        A utility static function can return an HTML table from a query string
        or cursor for general use in addition to adding it to an email body.
    */
-- See note in deployment file if you get ORA-24247 upon execution.
/*
MIT License

Copyright (c) 2021 Lee Lindley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/
--
--
--    Note that you do not put in the <header></header><body></body> tags as the
--    send procedure will do that.
--    The Subject will become the HTML title in the header.
--
--    Here is an example that puts the results of a query both into the body of
--    the email as an HTML table as well as attaching it as an XLSX file. 
--
--    DECLARE
--        v_email         html_email_udt;
--        v_src           SYS_REFCURSOR;
--        v_query         VARCHAR2(32767) := q'!SELECT --+ no_parallel 
--                v.view_name AS "View Name"
--                ,c.comments AS "Comments"
--            FROM dictionary d
--            INNER JOIN all_views v
--                ON v.view_name = d.table_name
--            LEFT OUTER JOIN all_tab_comments c
--                ON c.table_name = v.view_name
--            WHERE d.table_name LIKE 'ALL%'
--            ORDER BY v.view_name
--            FETCH FIRST 40 ROWS ONLY!';
--        --
--        -- Because you cannot CLOSE/ReOPEN a dynamic sys_refcursor variable directly,
--        -- you must regenerate it and assign it. Weird restriction, but do not
--        -- try to fight it by opening it in the main code twice. Get a fresh copy from a function.
--        FUNCTION l_getcurs RETURN SYS_REFCURSOR IS
--            l_src       SYS_REFCURSOR;
--        BEGIN
--            OPEN l_src FOR v_query;
--            RETURN l_src;
--        END;
--    BEGIN
--        v_email := html_email_udt(
--            p_to_list   => 'myname@google.com, yourname@yahoo.com'
--            ,p_from_email_addr  => 'myname@mycompany.com'
--            ,p_reply_to         => 'donotreply@nohost'
--            ,p_smtp_server      => 'smtp.mycompany.com'
--            ,p_subject          => 'A sample email from html_email_udt'
--        );
--        v_email.add_paragraph('We constructed and sent this email with html_email_udt.');
--        v_src := l_getcurs;
--        --v_email.add_to_body(html_email_udt.cursor_to_table(p_refcursor => v_src, p_caption => 'DBA Views'));
--        v_email.add_table_to_body(p_refcursor => v_src, p_caption => 'DBA Views');
--        -- we need to close it because we are going to open again.
--        -- The called package may have closed it, but must be sure or nasty 
--        -- bugs/caching can happen.
--        BEGIN
--            CLOSE v_src;
--        EXCEPTION WHEN invalid_cursor THEN NULL;
--        END;
--
--        -- https://github.com/mbleron/ExcelGen
--        DECLARE
--            l_xlsx_blob     BLOB;
--            l_ctxId         ExcelGen.ctxHandle;
--            l_sheet_handle  BINARY_INTEGER;
--        BEGIN
--            v_src := l_getcurs;
--            l_ctxId := ExcelGen.createContext();
--            l_sheet_handle := ExcelGen.addSheetFromCursor(l_ctxId, 'DBA Views', v_src, p_tabColor => 'green');
--            BEGIN
--                CLOSE v_src;
--            EXCEPTION WHEN invalid_cursor THEN NULL;
--            END;
--            ExcelGen.setHeader(l_ctxId, l_sheet_handle, p_frozen => TRUE);
--
--            v_email.add_attachment(p_file_name => 'dba_views.xlsx', p_blob_content => ExcelGen.getFileContent(l_ctxId));
--
--            excelGen.closeContext(l_ctxId);
--        END;
--
--        v_email.add_paragraph('The attached spreadsheet should match what is in the html table above');
--        v_email.send;
--    END;
--
    attachments         arr_html_email_attachment_udt
    ,arr_to             arr_varchar2_udt
    ,arr_cc             arr_varchar2_udt
    ,arr_bcc            arr_varchar2_udt
    ,from_email_addr    VARCHAR2(4000)
    ,reply_to           VARCHAR2(4000)
    ,smtp_server        VARCHAR2(4000)
    ,subject            VARCHAR2(4000)
    ,body               CLOB]'
$if $$use_app_log $then
||q'[
    ,log                app_log_udt]'
$end
||q'[
    ,CONSTRUCTOR FUNCTION html_email_udt(
        p_to_list           VARCHAR2 DEFAULT NULL
        ,p_cc_list          VARCHAR2 DEFAULT NULL
        ,p_bcc_list         VARCHAR2 DEFAULT NULL
        ,p_from_email_addr  VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_reply_to         VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_smtp_server      VARCHAR2 DEFAULT 'localhost'
        ,p_subject          VARCHAR2 DEFAULT NULL
        ,p_body             CLOB DEFAULT NULL]'
$if $$use_app_log $then
        ||q'[
        ,p_log              app_log_udt DEFAULT NULL]'
$end
||q'[
    )
        RETURN SELF AS RESULT
    ,MEMBER PROCEDURE send
    ,MEMBER PROCEDURE add_paragraph(p_clob CLOB)
    ,MEMBER PROCEDURE add_to_body(p_clob CLOB)
    ,MEMBER PROCEDURE add_table_to_body( -- see cursor_to_table
        p_sql_string    CLOB            := NULL
        ,p_refcursor    SYS_REFCURSOR  := NULL
        ,p_caption      VARCHAR2        := NULL
    )
    -- these take strings that can have multiple comma separated email addresses
    ,MEMBER PROCEDURE add_to(p_to VARCHAR2) 
    ,MEMBER PROCEDURE add_cc(p_cc VARCHAR2)
    ,MEMBER PROCEDURE add_bcc(p_bcc VARCHAR2)
    ,MEMBER PROCEDURE add_subject(p_subject VARCHAR2)
    ,MEMBER PROCEDURE add_attachment(
        p_file_name     VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
        -- looks up the mime type from the file_name extension
    )
    ,MEMBER PROCEDURE add_attachment( -- just in case you need fine control
        p_attachment    html_email_attachment_udt
    )
    --
    -- cursor_to_table() converts either an open sys_refcursor or a SQL query 
    -- string (do not pass both) into an HTML table from the result set of the 
    -- query as a CLOB. By HTML table I mean the partial HTML between 
    -- <table>..</table> inclusive, not the header/body part.
    --
    -- Column value coversions are whatever the database decides, so if you want
    -- to format the results a certain way, do so in the query. Also give 
    -- column aliases for the table column headers to look nice.
    -- Beware to not use spaces in the column name aliases as 
    -- something munges them with _x0020_.
    --
    -- Example:
    --     l_clob := html_email_udt.cursor_to_table(
    --                     p_caption      => 'Payroll Report'
    --                    ,p_sql_string   => q'!
    --                        SELECT
    --                            TO_CHAR(pidm) AS "Employee_PIDM_ID"
    --                            ,TO_CHAR(sum_salary, 'S999,999.99') AS "Salary"
    --                            ,TO_CHAR(payroll_date, 'MM/DD/YYYY') AS "Payroll_Date"
    --                        FROM some_table
    --                    !'
    --              );
    --
    -- You can pass the result to add_to_body() member procedure here, or you 
    -- can use it to construct html separate from this Object. The code is
    -- surprisingly short and sweet, and I pulled it off the interwebs mostly
    -- intact, so feel free to just steal that procedure and use it as you wish.
    --
    --Note: that if the cursor does not return any rows, we silently pass back
    -- a NULL clob
    ,STATIC FUNCTION cursor_to_table(
        -- pass in a string. 
        -- Unfortunately any tables that are not in your schema 
        -- will need to be fully qualified with the schema name. The cursor
        -- version does not share this issue.
        p_sql_string    CLOB            := NULL
        -- pass in an open cursor. This is better for my money.
        ,p_refcursor    SYS_REFCURSOR   := NULL
        -- if provided, will be the caption on the table, generally centered 
        -- on the top of the table by most renderers.
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
);
]'; -- end execute immediate
END; -- end anonymous block
/
show errors
CREATE OR REPLACE TYPE BODY html_email_udt AS

    CONSTRUCTOR FUNCTION html_email_udt(
        p_to_list           VARCHAR2 DEFAULT NULL
        ,p_cc_list          VARCHAR2 DEFAULT NULL
        ,p_bcc_list         VARCHAR2 DEFAULT NULL
        ,p_from_email_addr  VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_reply_to         VARCHAR2 DEFAULT 'donotreply@bogus.com'
        ,p_smtp_server      VARCHAR2 DEFAULT 'localhost'
        ,p_subject          VARCHAR2 DEFAULT NULL
        ,p_body             CLOB DEFAULT NULL
$if $$use_app_log $then
        ,p_log              app_log_udt DEFAULT NULL
$end
    )
    RETURN SELF AS RESULT
    IS
    BEGIN
        -- split will return an initialized, empty collection object if the 
        -- input string is null
        arr_to          := split(p_to_list,p_strip_dquote => 'N');
        arr_cc          := split(p_cc_list,p_strip_dquote => 'N');
        arr_bcc         := split(p_bcc_list,p_strip_dquote => 'N');
        from_email_addr := p_from_email_addr;
        reply_to        := p_reply_to;
        smtp_server     := p_smtp_server;
        subject         := p_subject;
        body            := p_body;
        attachments     := arr_html_email_attachment_udt();
$if $$use_app_log $then
        log             := NVL(p_log, app_log_udt('HTML_EMAIL_UDT'));
$end
        RETURN;
    END; -- end constructor html_email_udt

    MEMBER PROCEDURE add_to_body(p_clob CLOB)
    IS
    BEGIN
        body := body||p_clob;
    END; -- end add_to_body

    -- feel a bit silly with this since everyone should know enough html to do
    -- manually
    MEMBER PROCEDURE add_paragraph(p_clob CLOB)
    IS
    BEGIN
        IF body IS NULL THEN
            body := '<p>'||p_clob;
        ELSE
            body := body||'<br>
<br><p>'
                        ||p_clob;
        END IF;
    END; -- add_paragraph

    MEMBER PROCEDURE add_to(p_to VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := split(p_to, p_strip_dquote => 'N');
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_to.EXTEND;
            arr_to(arr_to.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_to


    MEMBER PROCEDURE add_cc(p_cc VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := split(p_cc, p_strip_dquote => 'N');
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_cc.EXTEND;
            arr_cc(arr_cc.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_cc

    MEMBER PROCEDURE add_bcc(p_bcc VARCHAR2)
    IS
        v_arr   arr_varchar2_udt;
    BEGIN
        v_arr := split(p_bcc, p_strip_dquote => 'N');
        FOR i IN 1..v_arr.COUNT
        LOOP
            arr_bcc.EXTEND;
            arr_bcc(arr_bcc.COUNT) := v_arr(i);
        END LOOP;
    END; -- end add_bcc

    MEMBER PROCEDURE add_subject(p_subject VARCHAR2)
    IS
    BEGIN
        subject := p_subject;
    END;

    MEMBER PROCEDURE add_attachment(
        p_file_name     VARCHAR2
        ,p_clob_content CLOB DEFAULT NULL
        ,p_blob_content BLOB DEFAULT NULL
    )
    IS
    BEGIN
        add_attachment(
            html_email_attachment_udt(
                p_file_name
                ,p_clob_content
                ,p_blob_content
$if $$use_mime_type $then
                ,mime_type.get(p_file_name
                    , CASE WHEN p_blob_content IS NOT NULL THEN 'Y' END
                )
$else
                ,CASE WHEN p_blob_content IS NULL THEN 'text/plain' ELSE 'application/octet-stream' END
$end
            )
        );
    END; -- end add_attachment

    MEMBER PROCEDURE add_attachment( 
        p_attachment    html_email_attachment_udt
    ) IS
    BEGIN
        IF p_attachment.clob_content IS NULL AND p_attachment.blob_content IS NULL THEN
            raise_application_error(-20834,'both clob_content and blob_content in call to add_attachment were null');
        ELSIF p_attachment.clob_content IS NOT NULL AND p_attachment.blob_content IS NOT NULL THEN
            raise_application_error(-20834,'both clob_content and blob_content in call to add_attachment were NOT null');
        END IF;
        IF p_attachment.mime_type IS NULL THEN
            raise_application_error(-20834,'attachment mime_type cannot be null');
        END IF;
        attachments.EXTEND;
        attachments(attachments.COUNT) := p_attachment;
    END;

    MEMBER PROCEDURE add_table_to_body( -- see cursor_to_table
        p_sql_string    CLOB            := NULL
        ,p_refcursor    SYS_REFCURSOR   := NULL
        ,p_caption      VARCHAR2        := NULL
    ) IS
    BEGIN
        body := body||'<br>
<br>'
            ||html_email_udt.cursor_to_table(
                p_sql_string    => p_sql_string
                ,p_refcursor    => p_refcursor
                ,p_caption      => p_caption
              );
    END; -- end add_table_to_body

    STATIC FUNCTION cursor_to_table(
        -- either the CLOB or the cursor must be null
        p_sql_string    CLOB            := NULL 
        ,p_refcursor    SYS_REFCURSOR   := NULL
        ,p_caption      VARCHAR2        := NULL
    ) RETURN CLOB
    IS
        v_context       DBMS_XMLGEN.CTXHANDLE;
        v_table_xsl     XMLType;
        v_html          CLOB;

        invalid_arguments       EXCEPTION;
        PRAGMA exception_init(invalid_arguments, -20881);
        e_null_object_ref       EXCEPTION;
        PRAGMA exception_init(e_null_object_ref, -30625);

        -- 
        -- stylesheets and xml transforms are not something I really studied.
        -- this is cookie cutter code I got off the web
        -- The token __CAPTION__ is optionally replace by a title/caption for
        -- the top of the table
        -- 
        c_xsl CONSTANT VARCHAR2(1024) := q'!<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="html"/>
 <xsl:template match="/">
   <table border="1"> __CAPTION__
    <tr>
     <xsl:for-each select="/ROWSET/ROW[1]/*">
      <th><xsl:value-of select="name()"/></th>
     </xsl:for-each>
    </tr>
    <xsl:for-each select="/ROWSET/*">
    <tr>    
     <xsl:for-each select="./*">
      <td><xsl:value-of select="text()"/> </td>
     </xsl:for-each>
    </tr>
   </xsl:for-each>
  </table>
 </xsl:template>
</xsl:stylesheet>!';

    BEGIN

        IF p_refcursor IS NOT NULL THEN
            v_context := DBMS_XMLGEN.NEWCONTEXT(p_refcursor);
        ELSIF p_sql_string IS NOT NULL THEN
            v_context := DBMS_XMLGEN.NEWCONTEXT(p_sql_string);
        ELSE
            raise_application_error(-20881,'both p_sql_string and p_refcursor were null');
        END IF;
        -- set to 1 for xsi:nil="true"
        DBMS_XMLGEN.setNullHandling(v_context,1);

        IF p_caption IS NULL
        THEN
            v_table_xsl := XMLTYPE(regexp_replace(c_xsl, '__CAPTION__', ''));
        ELSE
            v_table_xsl := XMLType(regexp_replace(c_xsl, '__CAPTION__', '<caption>'||p_caption||'</caption>'));
        END IF;
        -- we have a context that contains an open cursor and we have an xsl 
        -- style sheet to transform it. Sequence here is
        --     1) Get an XMLType object from the context.
        --     2) Call the transform method of that XMLType object instance
        --          passing the XSL XMLType object as an argument.
        --     3) The result of the transform method is yet another XMLType
        --        object. Call the method getClobVal() from that object which
        --        returns a CLOB
        BEGIN
            v_html :=  DBMS_XMLGEN.GETXMLType(v_context, DBMS_XMLGEN.NONE).transform(v_table_xsl).getClobVal();
        EXCEPTION WHEN e_null_object_ref THEN 
            v_html := NULL; -- most likely the cursor returned no rows
$if $$use_app_log $then
            app_log_udt.log_p('html_email_udt', 'cursor_to_table executed cursor that returned no rows. Returning NULL');
$else
            DBMS_OUTPUT.put_line('cursor_to_table executed cursor that returned no rows. Returning NULL');
$end
        END;
        -- it can easily raise a different error than we trapped.
        -- Caller should handle exceptions as appropriate.
        RETURN v_html;
    END cursor_to_table;

    MEMBER PROCEDURE send 
    IS
        v_smtp              UTL_SMTP.connection;
        v_myhostname        VARCHAR2(255);

        c_chunk_size        CONSTANT INTEGER := 57;
        c_boundary          CONSTANT VARCHAR2(50) := '---=*jkal8KKzbrgLN24z#wq*=';

        --
        -- convenience procedures rather than spelling everything out each time we 
        -- write to the SMTP connection
        --
        -- w for write varchar with crlf
        PROCEDURE w(l_v VARCHAR2) IS
        BEGIN
            UTL_SMTP.write_data(v_smtp, l_v||UTL_TCP.crlf);
        END;
        -- wp for write plain varchar w/o crlf added
        PROCEDURE wp(l_v VARCHAR2) IS
        BEGIN
            UTL_SMTP.write_data(v_smtp, l_v);
        END;
        -- write clob. UTL_SMTP takes varchar and apparently some reason
        -- everyone sends chunks of 57 bytes at least on attachments. Might 
        -- as well for html clob in the main body too
        -- https://oracle-base.com/articles/misc/email-from-oracle-plsql#attachment
        PROCEDURE wc(l_c CLOB) IS
        BEGIN
            FOR j IN 0..TRUNC((DBMS_LOB.getlength(l_c) - 1) / c_chunk_size)
            LOOP
                -- do not throw cr/lf in the middle of this, so wp for
                -- write plain!!!  substr returns varchar2, so wp() handles fine
                wp(DBMS_LOB.substr(lob_loc => l_c
                                    ,amount => c_chunk_size
                                    ,offset => (j * c_chunk_size) + 1
                    ) 
                );
            END LOOP; -- end for the chunks this attachment
            w(UTL_TCP.crlf); -- two crlf after clob attachment
        END;

        -- write blob.
        -- https://oracle-base.com/articles/misc/email-from-oracle-plsql#attachment
        PROCEDURE wb(l_b BLOB) IS
        BEGIN
            FOR j IN 0..TRUNC((DBMS_LOB.getlength(l_b) - 1) / c_chunk_size)
            LOOP
                UTL_SMTP.write_data(v_smtp
                    ,UTL_RAW.cast_to_varchar2(
                        UTL_ENCODE.base64_encode(
                            DBMS_LOB.substr(lob_loc => l_b
                                            ,amount => c_chunk_size
                                            ,offset => (j * c_chunk_size) + 1
                            )
                        )
                     )|| UTL_TCP.crlf -- a crlf after every chunk!!!
                );
            END LOOP;
            UTL_SMTP.write_data(v_smtp, UTL_TCP.crlf); -- write one more crlf after blob attachment
        END;
--
-- start main procedure body
--
    BEGIN
$if $$use_app_parameter $then
        IF NOT app_parameter.is_matching_database THEN
            -- This is the scenario that we are a database cloned from 
            -- production and if we run using the parameters containing 
            -- production email addresses, we are going to spam our business 
            -- users and partners from our test region. This check will prevent
            -- that and give us a chance to update the parameters for this 
            -- database region.
    $if $$use_app_log $then
            log.log_p('app_parameter.is_matching_database returned FALSE. Will return without sending mail');
    $else
            DBMS_OUTPUT.put_line('app_parameter.is_matching_database returned FALSE. Will return without sending mail');
    $end
            RETURN;
        END IF;
$end
        IF arr_to.COUNT + arr_cc.COUNT + arr_bcc.COUNT = 0 THEN
            raise_application_error(-20835,'no recipients were provided before calling html_email_udt.send');
        END IF;

        v_smtp := UTL_SMTP.open_connection(smtp_server, 25);

        -- open the connection to remote (or local) mail server and say hello!
        v_myhostname := SYS_CONTEXT('USERENV','SERVER_HOST');
        UTL_SMTP.helo(v_smtp, v_myhostname);
        UTL_SMTP.mail(v_smtp, from_email_addr);
        
        --
        -- tell the server about all the recipients
        --
        FOR i IN 1..arr_to.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_to(i));
        END LOOP;
        FOR i IN 1..arr_cc.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_cc(i));
        END LOOP;
        FOR i IN 1..arr_bcc.COUNT
        LOOP
            UTL_SMTP.rcpt(v_smtp, arr_bcc(i));
        END LOOP;

        --
        -- Now open for write the main data stream
        --
        UTL_SMTP.open_data(v_smtp);

        --
        -- recipients in the From and To lists, but not bcc.
        -- get to be visible in the email.
        --
        w('From: '||from_email_addr);

        IF reply_to IS NOT NULL THEN
            w('Reply-To:'||reply_to);
        END IF;

        FOR i IN 1..arr_to.COUNT
        LOOP
            w('To: '||arr_to(i));
        END LOOP;

        FOR i IN 1..arr_cc.COUNT
        LOOP
            w('Cc: '||arr_cc(i));
        END LOOP;
        
        w('Subject: '||subject);

        --
        -- done with preliminary information in the message header.
        -- Now we do the multi-part body where the message itself
        -- being HTML is a part.
        --
        w('MIME-Version: 1.0');
        IF attachments.COUNT = 0 THEN
            w('Content-Type: multipart/alternative; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        ELSE
            w('Content-Type: multipart/mixed; boundary="'||c_boundary||'"'||UTL_TCP.crlf); -- need extra crlf
        END IF;
        w('--'||c_boundary);
        -- first part is the html email body
        w('Content-Type: text/html; charset="iso-8859-1"'||UTL_TCP.crlf); -- need extra crlf
        -- we generate the html/head/title/body tags for our document.
        -- Our inputs will be the middle of the html document.
        wp('<!doctype html>
<html><head><title>'||subject||'</title></head>
<body>');
        --
        -- the clob with the html the caller provided for the body, either
        -- all at once or by calling methods we provided to add pieces. Use wc()
        -- because CLOB needs to be done in chunks
        --
        wc(body); 

        -- finish off the html and pad the end of the "part" with line endings 
        -- per the rules
        w('</body></html>'||UTL_TCP.crlf); -- need extra crlf

        IF attachments.COUNT > 0 THEN
            FOR i IN 1..attachments.COUNT
            LOOP
                w('--'||c_boundary); -- end the last multipart which may have
                                     -- just been the HTML document
                w('Content-Type: '||attachments(i).mime_type);
                IF attachments(i).clob_content IS NOT NULL THEN
                    --w('Content-Type: text/plain');
                    -- since it is CLOB, it is char data by definition.
                    w('Content-Transfer-Encoding: text/plain'); 
                    w('Content-Disposition: attachment; filename="'||attachments(i).file_name||'"'||UTL_TCP.crlf); -- extra crlf
                    wc(attachments(i).clob_content); -- writes the clob in chunks
                ELSE -- blob instead of clob
                    --w('Content-Type: application/octet-stream');
                    w('Content-Transfer-Encoding: base64'); 
                    w('Content-Disposition: attachment; filename="'||attachments(i).file_name||'"'||UTL_TCP.crlf); -- extra crlf
                    wb(attachments(i).blob_content);
                END IF;
            END LOOP; -- end foreach attachment
        END IF;

        -- final boundary closes out the mail body whether last thing written was the html message part
        -- or an attachment part. trailing '--' seals the deal.
        w('--'||c_boundary||'--'); 

        -- Now hang up the connection
        UTL_SMTP.close_data(v_smtp);
        UTL_SMTP.quit(v_smtp);

$if $$use_app_log $then
        log.log_p('html mail sent to '||TO_CHAR(arr_to.COUNT + arr_cc.COUNT + arr_bcc.COUNT)
                        ||' recipients'
                        ||CASE WHEN attachments.COUNT > 0 
                               THEN ' with '||TO_CHAR(attachments.COUNT)||' attachments' 
                          END
        );
$end
        EXCEPTION WHEN OTHERS THEN
$if $$use_app_log $then
            log.log_p('sqlerrm    : '||SQLERRM);
            log.log_p('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            log.log_p('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
$else
            DBMS_OUTPUT.put_line('sqlerrm    : '||SQLERRM);
            DBMS_OUTPUT.put_line('backtrace  : '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            DBMS_OUTPUT.put_line('callstack  : '||DBMS_UTILITY.FORMAT_CALL_STACK);
$end
            RAISE;

    END; -- send

END;
/
show errors
ALTER SESSION SET plsql_optimize_level=2;
ALTER SESSION SET plsql_code_type = INTERPRETED;
-- NOT granting to public. could spam
--GRANT EXECUTE ON html_email_udt TO ???;
