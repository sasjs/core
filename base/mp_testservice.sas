/**
  @file mp_testservice.sas
  @brief Will execute a test against a SASjs web service on SAS 9 or Viya
  @details Prepares the input files and retrieves the resulting datasets from
  the response JSON.

      %mp_testjob(
        duration=60*5
      )

  Note - the _webout fileref should NOT be assigned prior to running this macro.

  @param [in] program The _PROGRAM endpoint to test
  @param [in] inputfiles=(0) A list of space seperated fileref:filename pairs as
    follows:
        inputfiles=inref:filename inref2:filename2
  @param [in] inputparams=(0) A dataset containing name/value pairs in the
    following format:
    |name:$32|value:$1000|
    |---|---|
    |stpmacname|some value|
    |mustbevalidname|can be anything, oops, %abort!!|

  @param [in] debug= (log) Provide the _debug value
  @param [out] outlib= (0) Output libref to contain the final tables.  Set to
    0 if the service output is not in JSON format.
  @param [out] outref= (0) Output fileref to create, to contain the full _webout
    response.

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mp_abort.sas
  @li mp_binarycopy.sas
  @li mv_getjobresult.sas
  @li mv_jobflow.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mp_testservice(program,
  inputfiles=0,
  inputparams=0,
  debug=log,
  outlib=0,
  outref=0
)/*/STORE SOURCE*/;

/* sanitise inputparams */
%local pcnt;
%let pcnt=0;
%if &inputparams ne 0 %then %do;
  data _null_;
    set &inputparams;
    if not nvalid(name,'v7') then putlog (_all_)(=);
    else if name in (
      'program','inputfiles','inputparams','debug','outlib','outref'
    ) then putlog (_all_)(=);
    else do;
      x+1;
      call symputx(name,quote(cats(value)),'l');
      call symputx('pval'!!left(x),name,'l');
      call symputx('pcnt',x,'l');
    end;
  run;
  %mp_abort(iftrue= (%mf_nobs(&inputparams) ne &pcnt)
    ,mac=&sysmacroname
    ,msg=%str(Invalid values in &inputparams)
  )
%end;

/* parse the input files */
%local webcount i var;
%if %quote(&inputfiles) ne 0 %then %do;
  %let webcount=%sysfunc(countw(&inputfiles));
  %put &=webcount;
  %do i=1 %to &webcount;
    %let var=%scan(&inputfiles,&i,%str( ));
    %local webfref&i webname&i;
    %let webref&i=%scan(&var,1,%str(:));
    %let webname&i=%scan(&var,2,%str(:));
    %put webref&i=&&webref&i;
    %put webname&i=&&webname&i;
  %end;
%end;
%else %let webcount=0;


%local fref1 webref;
%let fref1=%mf_getuniquefileref();
%let webref=%mf_getuniquefileref();

%local platform;
%let platform=%mf_getplatform();
%if &platform=SASMETA %then %do;
  proc stp program="&program";
    inputparam _program="&program"
  %do i=1 %to &webcount;
    %if &webcount=1 %then %do;
      _webin_fileref="&&webref&i"
      _webin_name="&&webname&i"
    %end;
    %else %do;
      _webin_fileref&i="&&webref&i"
      _webin_name&i="&&webname&i"
    %end;
  %end;
    _webin_file_count="&webcount"
    _debug="&debug"
  %do i=1 %to &pcnt;
    /* resolve name only, proc stp fetches value */
    &&pval&i=&&&&&&pval&i
  %end;
    ;
  %do i=1 %to &webcount;
    inputfile &&webref&i;
  %end;
    outputfile _webout=&webref;
  run;

  data _null_;
    infile &webref;
    file &fref1;
    input;
    length line $10000;
    if index(_infile_,'>>weboutBEGIN<<') then do;
        line=tranwrd(_infile_,'>>weboutBEGIN<<','');
        put line;
    end;
    else if index(_infile_,'>>weboutEND<<') then do;
        line=tranwrd(_infile_,'>>weboutEND<<','');
        put line;
        stop;
    end;
    else put _infile_;
  run;
  data _null_;
    infile &fref1;
    input;
    put _infile_;
  run;
  %if &outlib ne 0 %then %do;
    libname &outlib json (&fref1);
  %end;
  %if &outref ne 0 %then %do;
    filename &outref temp;
    %mp_binarycopy(inref=&webref,outref=&outref)
  %end;

%end;
%else %if &platform=SASVIYA %then %do;
  data ;
    _program="&program";
  run;

  %mv_jobflow(inds=&syslast
    ,maxconcurrency=1
    ,outds=work.results
    ,outref=&fref1
  )
  /* show the log */
  data _null_;
    infile &fref1;
    input;
    putlog _infile_;
  run;
  /* get the uri to fetch results */
  data _null_;
    set work.results;
    call symputx('uri',uri);
  run;
  /* fetch results from webout.json */
  %mv_getjobresult(uri=&uri,
    result=WEBOUT_JSON,
    outref=&outref,
    outlib=&outlib
  )

%end;
%else %do;
  %put %str(ERR)OR: Unrecognised platform:  &platform;
%end;

filename &webref clear;

%mend;