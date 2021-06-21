/**
  @file
  @brief Get metadata permissions for a particular folder
  @details Uses the metadata batch tools to fetch the permissions for a
  particular folder. For security, the username / password are expected to have
  been provided in a protected directory.

Usage:

    %* import the macros (or make them available some other way);
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* create sample text file as input to the macro;
    %* password must be in single quotes if it has special chars;

    filename creds temp;
    data _null_;
      file creds;
      put " -user 'sasdemo' -password 'Mars321' ";
    run;

    filename outref "%sysfunc(pathname(work))";
    %mmx_getmetaperms(
        metaloc=/some/meta/folder
        ,secureref=creds
        ,outds=work.perms
    )

  <h4> SAS Macros </h4>
  @li mf_loc.sas
  @li mf_getuniquefileref.sas
  @li mp_abort.sas

  @param metaloc= the metadata folder for which to export permissions
  @param secureref= fileref containing the username / password (should point to
    a file in a secure location)
  @param outds= (work.mmx_getmetaperms) The output table containing the perms
  @param effective= (YES) Displays effective access. If set to NO, only direct
    access controls are displayed. Effective access is the net effect of all
    applicable permission settings (both direct access controls and inherited
    permissions).
  @param onlyGroup= (0) Display access for only the specified user group.
  @param onlyUser= (0) Display access for only the specified user.

  @version 9.4
  @author Allan Bowe

**/

%macro mmx_getmetaperms(metaloc=
  ,secureref=
  ,outds=work.mmx_getmetaperms
  ,effective=YES
  ,onlygroup=0
  ,onlyuser=0
);

%local host port path mmxuser mmxpass eff filt;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let path=%mf_loc(POF)/tools/sas-show-metadata-access;

%if &effective=YES %then %let eff=-effective;
%if "&onlygroup" ne "0" %then %let filt=-onlyGroup ""&onlygroup"";
%else %if "&onlyuser" ne "0" %then %let filt=-onlyUser ""&onlyuser"";

%local fref1;
%let fref1=%mf_getuniquefileref();
data _null_;
  file &fref1 lrecl=32767;
  infile &secureref;
  input;
  put 'data _null_;';
  put "infile '&path -disableX11 -host &host -port &port " _infile_ @;
  put " ""&metaloc"" &eff &filt 2>&1' pipe lrecl=10000;";
  put 'input;putlog _infile_;run;';
run;

data _null_;
  infile &fref1;
  input;list;run;

%inc &fref1/nosource;


%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc on exit)
)


%mend mmx_getmetaperms;