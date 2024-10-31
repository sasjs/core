/**
  @file
  @brief Triggers a SASjs Server STP using the /SASjsApi/stp/trigger endpoint
  @details Triggers the STP and returns the sessionId

  Example:

      %ms_triggerstp(/some/stored/program
        ,debug=131
        ,outds=work.myresults
      )

  @param [in] pgm The full path to the Stored Program in SASjs Drive (_program
    parameter)
  @param [in] debug= (131) The value to supply to the _debug URL parameter
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [in] inputparams=(_null_) A dataset containing name/value pairs in the
    following format:
    |name:$32|value:$10000|
    |---|---|
    |stpmacname|some value|
    |mustbevalidname|can be anything, oops, %abort!!|
  @param [in] inputfiles= (_null_) A dataset containing fileref/name/filename in
    the following format:
    |fileref:$8|name:$32|filename:$256|
    |---|---|--|
    |someref|some_name|some_filename.xls|
    |fref2|another_file|zyx_v2.csv|
  @param [in] expiresaftermins= (15) The number of minutes to retain the session
    folder after the session ends.

  @param [out] outds= (work.ms_triggerstp) Set to the name of a dataset to
  contain the sessionId. If this dataset already exists, and contains the
  sessionId, it will be appended to.
  Format:
    |sessionId:$36|
    |---|
    |20241028074744-54132-1730101664824|

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_getuniquename.sas
  @li mp_abort.sas
  @li mp_dropmembers.sas
  @li mf_nobs.sas

**/

%macro ms_triggerstp(pgm
    ,debug=131
    ,inputparams=_null_
    ,inputfiles=_null_
    ,expiresAfterMins=15
    ,outds=work.ms_triggerstp
    ,mdebug=0
  );
  %local dbg mainref authref boundary libref triggered_sid;
  %let mainref=%mf_getuniquefileref();
  %let authref=%mf_getuniquefileref();
  %let boundary=%mf_getuniquename();
  %if &inputparams=0 %then %let inputparams=_null_;

  %if &mdebug=1 %then %do;
    %put &sysmacroname entry vars:;
    %put _local_;
  %end;
  %else %let dbg=*;


  %mp_abort(iftrue=("&pgm"="")
    ,mac=&sysmacroname
    ,msg=%str(Program not provided)
  )
  %mp_abort(iftrue=("&outds"="")
    ,mac=&sysmacroname
    ,msg=%str(Output dataset not provided)
  )

  /* avoid sending bom marker to API */
  %local optval;
  %let optval=%sysfunc(getoption(bomfile));
  options nobomfile;

  /* Add params to the content */
  data _null_;
    file &mainref termstr=crlf lrecl=32767 mod;
    length line $1000 name $32 value $32767;
    put "--&boundary";
    if _n_=1 then call missing(of _all_);
    set &inputparams;
    line=cats('Content-Disposition: form-data; name="',name,'"');
    put line;
    put ;
    put value;
  run;

  /* parse input file list */
  %local webcount;
  %let webcount=0;
  data _null_;
    set &inputfiles end=last;
    length fileref $8 name $32 filename $256;
    call symputx(cats('webref',_n_),fileref,'l');
    call symputx(cats('webname',_n_),name,'l');
    call symputx(cats('webfilename',_n_),filename,'l');
    if last then do;
      call symputx('webcount',_n_);
      call missing(of _all_);
    end;
  run;

  /* write out the input files to the content */
  %local i;
  %do i=1 %to &webcount;
    data _null_;
      file &mainref termstr=crlf lrecl=32767 mod;
      infile &&webref&i lrecl=32767;
      if _n_ = 1 then do;
        length line $32767;
        line=cats(
          'Content-Disposition: form-data; name="'
          ,"&&webname&i"
          ,'"; filename="'
          ,"&&webfilename&i"
          ,'"'
        );
        put "--&boundary";
        put line;
        put "Content-Type: text/plain";
        put ;
      end;
      input;
      put _infile_; /* add the actual file to be sent */
    run;
  %end;

  /* Add footer to the content */
  data _null_;
    file &mainref termstr=crlf mod;
    put / "--&boundary--";
  run;

  data _null_;
    file &authref lrecl=1000;
    infile "&_sasjs_tokenfile" lrecl=1000;
    input;
    if _n_=1 then put "Content-Type: multipart/form-data; boundary=&boundary";
    put _infile_;
  run;

  %if &mdebug=1 %then %do;
    data _null_;
      if _n_ eq 1 then putlog "NOTE: ***** authref=&authref content *****";
      infile &authref;
      input;
      put _infile_;
    data _null_;
      if _n_ eq 1 then putlog "NOTE: ***** mainref=&mainref content *****";
      infile &mainref;
      input;
      put _infile_;
    run;
  %end;

  %local resp_path outref;
  %let resp_path=%sysfunc(pathname(work))/%mf_getuniquename();
  %let outref=%mf_getuniquefileref();
  filename &outref "&resp_path" lrecl=32767;

  /* prepare request*/
  proc http method='POST' headerin=&authref in=&mainref out=&outref
    url="&_sasjs_apiserverurl/SASjsApi/stp/trigger?%trim(
      )_program=&pgm%str(&)_debug=131%str(&)expiresAfterMins=&expiresaftermins";
  %if &mdebug=1 %then %do;
    debug level=2;
  %end;
  run;

  %if (&SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201)
  or &mdebug=1
  %then %do;
    data _null_;
      if _n_ eq 1 then putlog "NOTE: ***** outref=&outref content *****";
      infile &outref;
      input;
      putlog _infile_;
    run;
  %end;
  %mp_abort(
    iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200
        and &SYS_PROCHTTP_STATUS_CODE ne 201)
    ,mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )

  /* reset options */
  options &optval;

  %let libref=%mf_getuniquelibref();
  libname &libref JSON fileref=&outref;
  %let triggered_sid=%mf_getuniquename(prefix=triggered_sid_);

  data work.&triggered_sid (keep=sessionid);
    set &libref..root;

    %if &mdebug=1 %then %do;
      putlog (_all_)(=);
    %end;
  run;

  %if %mf_nobs(work.&triggered_sid)>0 %then %do;
    proc append base=&outds data=work.&triggered_sid;
    run;
  %end;

  %if &mdebug=1 %then %do;
    %put &sysmacroname exit vars:;
    %put _local_;
  %end;
  %else %do;
    /* clear refs */
    filename &authref;
    filename &mainref;
    filename &outref;
    libname &libref clear;
    /* and remove temp dataset */
    %mp_dropmembers(&triggered_sid,libref=work);
  %end;

%mend ms_triggerstp;