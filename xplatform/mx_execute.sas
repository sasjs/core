/**
  @file
  @brief Will execute a SASjs web service on SAS 9, Viya or SASjs Server
  @details Prepares the input files and retrieves the resulting datasets from
  the response JSON.

  Note - the _webout fileref should NOT be assigned prior to running this macro.

  @param [in] program The _PROGRAM endpoint to test
  @param [in] inputfiles=(0) A list of space seperated fileref:filename pairs as
    follows:
        inputfiles=inref:filename inref2:filename2
  @param [in] inputdatasets= (0) All datasets in this space seperated list are
    converted into SASJS-formatted CSVs (see mp_ds2csv.sas) files and added to
    the list of `inputfiles` for ingestion.  The dataset will be sent with the
    same name (no need for a colon modifier).
  @param [in] inputparams=(0) A dataset containing name/value pairs in the
    following format:
    |name:$32|value:$1000|
    |---|---|
    |stpmacname|some value|
    |mustbevalidname|can be anything, oops, %abort!!|

  @param [in] debug= (131) Provide the _debug value.
  @param [in] mdebug= (0) Set to 1 to provide macro debugging
  @param [in] viyaresult= (WEBOUT_JSON) The Viya result type to return.  For
    more info, see mv_getjobresult.sas
  @param [in] viyacontext= (SAS Job Execution compute context) The Viya compute
    context on which to run the service
  @param [out] outlib= (0) Output libref to contain the final tables.  Set to
    0 if the service output is not in JSON format.
  @param [out] outref= (0) Output fileref to create, to contain the full _webout
    response.
  @param [out] outlogds= (_null_) Name of a dataset to receive the child's log
    (one column, line).  Populated on Viya, from the job log mv_jobflow
    collects, and on SASjs Server, from the log the server appends to the
    response - ms_testservice discards that log unless this is set.  Not
    populated on SAS 9, where proc stp returns no child log.  On SASjs Server
    it is only populated when debug is 131 or above: the server appends the log
    to the response in debug mode, so a lower value returns an empty dataset.
  @param [out] outstatus= (0) Name of a dataset to receive the outcome of each
    child run - one row per program, with columns STATE, URI, ERRMSG and
    PLATFORM.  ERRMSG is only populated on SASjs Server, from the abort block;
    the Viya job flow carries a state but no message, and SAS 9 gives neither.

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mp_abort.sas
  @li mp_binarycopy.sas
  @li mp_ds2csv.sas
  @li ms_testservice.sas
  @li mv_getjobresult.sas
  @li mv_jobflow.sas
  @li mf_nobs.sas

  <h4> Related Programs </h4>
  @li mx_execute.test.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mx_execute(program,
  inputfiles=0,
  inputdatasets=0,
  inputparams=0,
  debug=131,
  mdebug=0,
  outlib=0,
  outref=0,
  outlogds=_null_,
  outstatus=0,
  viyaresult=WEBOUT_JSON,
  viyacontext=SAS Job Execution compute context
);
%local dbg pcnt fref1 fref2 webref webrefpath i webcount var platform jobds respref clearmeref;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

/* sanitise inputparams */
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
      call symputx(cats('pval',x),name,'l');
      call symputx('pcnt',x,'l');
    end;
  run;
  %mp_abort(iftrue= (%mf_nobs(&inputparams) ne &pcnt)
    ,mac=&sysmacroname
    ,msg=%str(Invalid values in &inputparams)
  )
%end;

/* convert inputdatasets to filerefs */
%if "&inputdatasets" ne "0" %then %do;
  %if %quote(&inputfiles)=0 %then %let inputfiles=;
  %do i=1 %to %sysfunc(countw(&inputdatasets,%str( )));
    %let var=%scan(&inputdatasets,&i,%str( ));
    %local dsref&i;
    %let dsref&i=%mf_getuniquefileref();
    %mp_ds2csv(&var,outref=&&dsref&i,headerformat=SASJS)
    %let inputfiles=&inputfiles &&dsref&i:%scan(&var,-1,.);
  %end;
%end;

%let platform=%mf_getplatform();
%let fref1=%mf_getuniquefileref();
%let fref2=%mf_getuniquefileref();
%let webref=%mf_getuniquefileref();
%let webrefpath=%sysfunc(pathname(work))/%mf_getuniquename();
/* mp_chop requires a physical path as input */
filename &webref "&webrefpath";

%if &platform=SASMETA %then %do;

  /* parse the input files */
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

  %if "&outlogds" ne "_null_" %then %do;
    /* SAS 9 returns no child log.  Create the dataset all the same, so a caller
      * that reads it gets no rows rather than a missing table. */
    data &outlogds;
      length line $32767;
      stop;
    run;
  %end;

  /* proc stp gives no job status - say so rather than imply success */
  %if "&outstatus" ne "0" %then %do;
    data &outstatus;
      length state $20 uri $256 errmsg $256 platform $10;
      state='unknown';
      uri='';
      errmsg='proc stp returns no job status';
      platform='SASMETA';
      output;
    run;
  %end;

%end;
%else %if &platform=SASVIYA %then %do;

  /* prepare inputparams */
  %local ds1;
  %let ds1=%mf_getuniquename();
  %if "&inputparams" ne "0" %then %do;
    proc transpose data=&inputparams out=&ds1;
      id name;
      var value;
    run;
  %end;
  %else %do;
    data &ds1;run;
  %end;

  /* parse the input files - convert to sasjs params */
  %local webcount i var sasjs_tables;
  %if %quote(&inputfiles) ne 0 %then %do;
    %let webcount=%sysfunc(countw(&inputfiles));
    %put &=webcount;
    %do i=1 %to &webcount;
      %let var=%scan(&inputfiles,&i,%str( ));
      %local webfref&i webname&i sasjs&i.data;
      %let webref&i=%scan(&var,1,%str(:));
      %let webname&i=%scan(&var,2,%str(:));
      %put webref&i=&&webref&i;
      %put webname&i=&&webname&i;

      %let sasjs_tables=&sasjs_tables &&webname&i;
      data _null_;
        infile &&webref&i lrecl=32767;
        input;
        if _n_=1 then call symputx("sasjs&i.data",_infile_);
        else call symputx(
          "sasjs&i.data",cats(symget("sasjs&i.data"),'0D0A'x,_infile_)
        );
        putlog "&sysmacroname infile: " _infile_;
      run;
      data &ds1;
        set &ds1;
        length sasjs&i.data $32767 sasjs_tables $1000;
        sasjs&i.data=symget("sasjs&i.data");
        sasjs_tables=symget("sasjs_tables");
      run;
    %end;
  %end;
  %else %let webcount=0;

  data &ds1;
    retain _program "&program";
    retain _contextname "&viyacontext";
    set &ds1;
    putlog "&sysmacroname inputparams:";
    putlog (_all_)(=);
  run;

  /* the flow table is an internal detail: unique name, thrown away below */
  %let jobds=%mf_getuniquename(prefix=mx_execute_);
  %mv_jobflow(inds=&ds1
    ,maxconcurrency=1
    ,outds=&jobds
    ,outref=&fref1
    ,mdebug=&mdebug
  )
  /* show the log */
  data _null_;
    infile &fref1;
    input;
    putlog _infile_;
  run;
  /* and keep it, if the caller asked */
  %if "&outlogds" ne "_null_" %then %do;
    data &outlogds;
      infile &fref1 lrecl=32767 end=eof;
      length line $32767;
      do while(not eof);
        input;
        output;
      end;
    run;
  %end;
  /* get the uri to fetch results */
  data _null_;
    set &jobds;
    call symputx('uri',uri);
    putlog "&sysmacroname: fetching results for " uri;
  run;
  /* the outcome, before the flow table goes away */
  %if "&outstatus" ne "0" %then %do;
    data &outstatus;
      length state $20 uri $256 errmsg $256 platform $10;
      platform='SASVIYA';
      errmsg='';
      set &jobds(keep=state uri);
    run;
  %end;
  /* nothing else needs the flow table - do not leave it in the caller's WORK */
  proc datasets lib=work nolist nowarn;
    delete &jobds;
  quit;
  /* fetch results from webout.json */
  %mv_getjobresult(uri=&uri,
    result=&viyaresult,
    outref=&outref,
    outlib=&outlib,
    mdebug=&mdebug
  )

%end;
%else %if &platform=SASJS %then %do;

  /* the response is needed to judge the outcome, even if not requested -
    * and only a ref we create here may be cleared afterwards */
  %let respref=&outref;
  %if "&respref"="0" and "&outstatus" ne "0" %then %do;
    %let respref=%mf_getuniquefileref();
    %let clearmeref=1;
  %end;
  %ms_testservice(&program
    ,inputfiles=&inputfiles
    ,inputdatasets=&inputdatasets
    ,inputparams=&inputparams
    ,debug=&debug
    ,mdebug=&mdebug
    ,outlib=&outlib
    ,outref=&respref
    ,outlogds=&outlogds
  )
  %if "&outstatus" ne "0" %then %do;
    data &outstatus;
      length state $20 uri $256 errmsg $256 platform $10;
      retain state 'completed' uri '' errmsg '' platform 'SASJS' abortseen 0;
      infile &respref end=eof lrecl=32767;
      /* scan the whole response - the abort block is not always on the first
        * line - but only take a message from inside that block, so a service
        * with its own MSG field does not look like an abort */
      do while(not eof);
        input;
        if index(_infile_,'"sasjsAbort"')>0 then do;
          state='canceled';
          abortseen=1;
        end;
        if abortseen=1 and errmsg='' and index(_infile_,'"MSG"')>0 then do;
          /* prxchange returns its input untouched when nothing matches, which
            * would put the whole line in errmsg */
          if prxmatch('/"MSG" *: *"([^"]*)"/',_infile_) then
            errmsg=prxchange('s/.*"MSG" *: *"([^"]*)".*/$1/',-1,_infile_);
        end;
      end;
      /* one row, whatever the response contained */
      output;
    run;
  %end;
  %if %length(&clearmeref)>0 %then %do;
    filename &respref clear;
  %end;

%end;
%else %do;
  %put %str(ERR)OR: Unrecognised platform:  &platform;
%end;

%if &mdebug=0 %then %do;
  filename &fref1 clear;
  %if &platform ne SASJS %then %do;
    filename &fref2 clear;
    filename &webref clear;
  %end;
%end;
%else %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;

%mend mx_execute;
