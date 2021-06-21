/**
  @file mmx_spkexport.sas
  @brief Exports everything in a particular metadata folder
  @details Will export everything in a metadata folder to a specified location.
    Note - the batch tools require a username and password.  For security,
    these are expected to have been provided in a protected directory.

Usage:

    %* import the macros (or make them available some other way);
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* create sample text file as input to the macro;
    filename tmp temp;
    data _null_;
      file tmp;
      put '%let mmxuser=sasdemo;';
      put '%let mmxpass=Mars321';
    run;

    filename outref "%sysfunc(pathname(work))";
    %mmx_spkexport(
        metaloc=%str(/30.Projects/3001.Internal/300115.DataController/dc1)
        ,secureref=tmp
        ,outspkpath=%str(/tmp)
    )

  <h4> SAS Macros </h4>
  @li mf_loc.sas
  @li mm_tree.sas
  @li mf_getuniquefileref.sas
  @li mp_abort.sas

  @param metaloc= the metadata folder to export
  @param secureref= fileref containing the username / password (should point to
    a file in a secure location)
  @param outspkname= name of the spk to be created (default is mmxport).
  @param outspkpath= directory in which to create the SPK.  Default is WORK.

  @version 9.4
  @author Allan Bowe

**/

%macro mmx_spkexport(metaloc=
  ,secureref=
  ,outspkname=mmxport
  ,outspkpath=%sysfunc(pathname(work))
);

%local host port platform_object_path connx_string;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let platform_object_path=%mf_loc(POF);

/* get creds */
%inc &secureref/nosource;

%let connx_string=
  %str(-host &host -port &port -user '&mmxuser' -password '&mmxpass');

%mm_tree(root=%str(&metaloc) ,types=EXPORTABLE ,outds=exportable)

%local fref1;
%let fref1=%mf_getuniquefileref();
data ;
  set exportable end=last;
  file &fref1 lrecl=32767;
  length str $32767;
  if _n_=1 then do;
    put 'data _null_;';
    put 'infile "cd ""&platform_object_path"" %trim(';
    put ') cd ""&platform_object_path"" %trim(';
    put '); ./ExportPackage &connx_string -disableX11 %trim(';
    put ') -package ""&outspkpath/&outspkname..spk"" %trim(';
  end;
  str=') -objects '!!cats('""',path,'/',name,"(",publictype,')"" %trim(');
  put str;
  if last then do;
    put ') -log ""&outspkpath/&outspkname..log"" 2>&1" pipe lrecl=10000;';
    put 'input;putlog _infile_;run;';
  end;
run;

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc)
)

%inc &fref1;

%mend mmx_spkexport;