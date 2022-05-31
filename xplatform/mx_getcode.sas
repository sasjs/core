/**
  @file
  @brief Fetches code from Viya Job, SAS 9 STP, or SASjs Server STP
  @details  When building applications that run on multiple flavours of SAS, it
  is convenient to use a single macro (like this one) to fetch the source
  code from a Viya Job, SAS 9 Stored Process, or SASjs Stored Program.

  The alternative would be to compile a generic macro in target-specific
  folders (SASVIYA, SAS9 and SASJS).  This avoids compiling unnecessary macros
  at the expense of a more complex sasjsconfig.json setup.


  @param [in] loc The full path to the Viya Job, SAS 9 Stored Process or SASjs
    Stored Program in Drive or Metadata, WITHOUT the .sas extension (SASjs only)
  @param [out] outref= (0) The fileref to create, which will contain the source
    code.

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mm_getstpcode.sas
  @li ms_getfile.sas
  @li mv_getjobcode.sas

  @author Allan Bowe

**/

%macro mx_getcode(loc,outref=0
)/*/STORE SOURCE*/;

%local platform name shortloc;
%let platform=%mf_getplatform();

%if &platform=SASJS %then %do;
  %ms_getfile(&loc..sas, outref=&outref)
%end;
%else %if &platform=SAS9 or &platform=SASMETA %then %do;
  %mm_getstpcode(tree=&loc,outloc=&outref)
%end;
%else %if &platform=SASVIYA %then %do;
  /* extract name & path from &loc */
  data _null_;
    loc=symget('loc');
    name=scan(loc,-1,'/');
    shortloc=substr(loc,1,length(loc)-length(name)-1);
    call symputx('name',name,'l');
    call symputx('shortloc',shortloc,'l');
  run;
  %mv_getjobcode(
    path=&shortloc,
    name=&name,
    outref=&outref
  )
%end;
%else %put &sysmacroname: &platform is unsupported!!!;

%mend mx_getcode;
