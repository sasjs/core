/**
  @file
  @brief Add or update an extension to an application component
  @details A SAS Application (SoftwareComponent) is a great place to store app
    specific parameters.  There are two main places those params can be stored:
    1) Configuration, and 2) Extensions.  The second location will enable end
    users to modify parameters even if they don't have the Configuration Manager
    plugin in SMC.  This macro can be used after creating an application with
    the mm_createapplication.sas macro.  If a parameter with the same name
    exists, it is updated.  If it does not, it is created.

  Usage:

    %mm_updateappextension(app=/my/metadata/path/myappname
      ,paramname=My Param
      ,paramvalue=My value
      ,paramdesc=some description)


  @param app= the BIP Tree folder path plus Application Name
  @param paramname= Parameter name
  @param paramvalue= Parameter value
  @param paramdesc= Parameter description

  @param frefin= change default inref if it clashes with an existing one
  @param frefout= change default outref if it clashes with an existing one
  @param mDebug= set to 1 to show debug messages in the log

  @version 9.4
  @author Allan Bowe

**/

%macro mm_updateappextension(app=
  ,paramname=
  ,paramvalue=
  ,paramdesc=Created by mm_updateappextension
  ,frefin=inmeta,frefout=outmeta
  , mdebug=0);


/* first, check if app (and param) exists */
%local appuri exturi;
%let appuri=stopifempty;
%let exturi=createifempty;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  paramname=symget('paramname');
  path="&app(Application)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"Application",type,uri)>0 then do;
    /* we have an app in this location! */
    call symputx('appuri',uri,'l');
    cnt=1;
    do while (metadata_getnasn(uri,"Extensions",cnt,tsuri)>0);
      rc=metadata_getattr(tsuri,"Name",value);
      put tsuri= value=;
      if value=paramname then do;
        putlog "&sysmacroname: found existing param - " tsuri;
        rc=metadata_getattr(tsuri,"Id",value);
        call symputx('exturi',value,'l');
        stop;
      end;
      cnt+1;
    end;
  end;
  else put (_all_)(=);
run;

%if &appuri=stopifempty %then %do;
  %put WARNING:  &app.(Application) not found!;
  %return;
%end;

/* escape the description so it can be stored as XML  */
data _null_;
  length outstr $32767;
  outstr=symget('paramdesc');
  outstr=tranwrd(outstr,'&','&amp;');
  outstr=tranwrd(outstr,'<','&lt;');
  outstr=tranwrd(outstr,'>','&gt;');
  outstr=tranwrd(outstr,"'",'&apos;');
  outstr=tranwrd(outstr,'"','&quot;');
  outstr=tranwrd(outstr,'0A'x,'&#10;');
  outstr=tranwrd(outstr,'0D'x,'&#13;');
  outstr=tranwrd(outstr,'$','&#36;');
  call symputx('paramdesc',outstr,'l');
run;

filename &frefin temp;

%if &exturi=createifempty %then %do;
  /* write header XML */
  data _null_;
    file &frefin;
    pname=quote(trim(symget('paramname')));
    pdesc=quote(trim(symget('paramdesc')));
    pvalue=quote(trim(symget('paramvalue')));
    put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>"/
        "  <SoftwareComponent id='&appuri' ><Extensions>" /
        '    <Extension Name=' pname ' Desc=' pdesc ' value= ' pvalue ' />' /
        '  </Extensions></SoftwareComponent>'/
        '</Metadata><NS>SAS</NS><Flags>268435456</Flags></UpdateMetadata>';
  run;

%end;
%else %do;
  data _null_;
    file &frefin;
    pdesc=quote(trim(symget('paramdesc')));
    pvalue=quote(trim(symget('paramvalue')));
    put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>"/
        "  <Extension id='&exturi' Desc=" pdesc ' value= ' pvalue ' />' /
        '</Metadata><NS>SAS</NS><Flags>268435456</Flags></UpdateMetadata>';
  run;
%end;

filename &frefout temp;

proc metadata in= &frefin out=&frefout verbose;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=1048576;
    input;
    put _infile_;
  run;
%end;

%mend;