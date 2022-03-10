/**
  @file mm_spkexport.sas
  @brief Creates an batch spk export command
  @details Creates a script that will export everything in a metadata folder to
    a specified location.
    If you have XCMD enabled, then you can use mmx_spkexport (which performs
    the actual export)

    Note - the batch tools require a username and password.  For security,
    these are expected to have been provided in a protected directory.

  Usage:

      %* import the macros (or make them available some other way);
      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* create sample text file as input to the macro;
      filename tmp temp;
      data _null_;
        file tmp;
        put '%let mmxuser="sasdemo";';
        put '%let mmxpass="Mars321";';
      run;

      filename myref "%sysfunc(pathname(work))/mmxexport.sh"
        permission='A::u::rwx,A::g::r-x,A::o::---';
      %mm_spkexport(metaloc=%str(/my/meta/loc)
          ,outref=myref
          ,secureref=tmp
          ,cmdoutloc=%str(/tmp)
      )

  Alternatively, call without inputs to create a function style output

      filename myref "/tmp/mmscript.sh"
        permission='A::u::rwx,A::g::r-x,A::o::---';
      %mm_spkexport(metaloc=%str(/my/meta/loc)
          outref=myref
          ,cmdoutloc=%str(/tmp)
          ,cmdoutname=mmx
      )

  You can then navigate and execute as follows:

      cd /tmp
      ./mmscript.sh "myuser" "mypass"


  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_isblank.sas
  @li mf_loc.sas
  @li mm_tree.sas
  @li mp_abort.sas


  @param [in] metaloc= the metadata folder to export
  @param [in] secureref= fileref containing the username / password (should
    point to a file in a secure location). Leave blank to substitute $bash vars.
  @param [in] excludevars= (0) A space seperated list of macro variable names,
    each of which contains a value that should be used to filter the output
    objects.
  @param [out] outref= fileref to which to write the command
  @param [out] cmdoutloc= (%sysfunc(pathname(work))) The directory to which the
    command will write the SPK
  @param [out] cmdoutname= (mmxport) The name of the spk / log files to create
    (will be identical just with .spk or .log extension)

  @version 9.4
  @author Allan Bowe

**/

%macro mm_spkexport(metaloc=
  ,secureref=
  ,excludevars=0
  ,outref=
  ,cmdoutloc=%sysfunc(pathname(work))
  ,cmdoutname=mmxport
);

%if &sysscp=WIN %then %do;
  %put %str(WARN)ING: the script has been written assuming a unix system;
  %put %str(WARN)ING- it will run anyway as should be easy to modify;
%end;

/* set creds */
%local mmxuser mmxpath i var;
%let mmxuser=$1;
%let mmxpass=$2;
%if %mf_isblank(&secureref)=0 %then %do;
  %inc &secureref/nosource;
%end;

/* setup metadata connection options */
%local host port platform_object_path ds;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let platform_object_path=%mf_loc(POF);
%let ds=%mf_getuniquename(prefix=spkexportable);

%mm_tree(root=%str(&metaloc) ,types=EXPORTABLE ,outds=&ds)

%if %mf_isblank(&outref)=1 %then %let outref=%mf_getuniquefileref();

data _null_;
  set &ds end=last;
  file &outref lrecl=32767;
  length str $32767;
  if _n_=1 then do;
    put "cd ""&platform_object_path"" \";
    put "; ./ExportPackage -host &host -port &port -user &mmxuser \";
    put "  -disableX11 -password &mmxpass \"
    put "  -package ""&cmdoutloc/&cmdoutname..spk"" \";
  end;
/* exclude particular patterns from the exported SPK */
%if "&excludevars" ne "0" %then %do;
  /* ignore top level folder else all subcontent will be exported regardless */
  if _n_>1;
  %do i=1 %to %sysfunc(countw(&excludevars));
    %let var=%scan(&excludevars,&i);
    if index(path,symget("&var")) ne 0;
  %end;
%end;
  str=' -objects '!!cats('"',path,'/',name,"(",publictype,')" \');
  put str;
  if last then put " -log ""&cmdoutloc/&cmdoutname..log"" 2>&1 ";
run;

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=mm_spkexport
  ,msg=%str(syscc=&syscc)
)

%mend mm_spkexport;
