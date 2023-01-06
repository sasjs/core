/**
  @file
  @brief Will execute a SASjs web service on SASjs Server
  @details Prepares the input files and retrieves the resulting datasets from
  the response JSON.

  @param [in] program The Stored Program endpoint to test
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

  @param [in] debug= (131) Provide the _debug value to pass to the STP
  @param [in] mdebug= (0) Set to 1 to provide macro debugging (this macro)
  @param [out] outlib= (0) Output libref to contain the final tables.  Set to
    0 if the service output is not in JSON format.
  @param [out] outref= (0) Output fileref to create, to contain the full _webout
    response.
  @param [out] outlogds= (_null_) Set to the name of a dataset to contain the
    log. Table format:
    |line:$2000|
    |---|
    |log line 1|
    |log line 2|

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mp_abort.sas
  @li mp_binarycopy.sas
  @li mp_chop.sas
  @li mp_ds2csv.sas
  @li ms_runstp.sas

  <h4> Related Programs </h4>
  @li mp_testservice.test.sas

  @version 9.4
  @author Allan Bowe

**/

%macro ms_testservice(program,
  inputfiles=0,
  inputdatasets=0,
  inputparams=0,
  debug=0,
  mdebug=0,
  outlib=0,
  outref=0,
  outlogds=_null_
)/*/STORE SOURCE*/;
%local dbg i var ds1 fref1 chopout1 chopout2;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

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

/* parse the filerefs - convert to a dataset */
%let ds1=%mf_getuniquename();
data &ds1;
  length fileref $8 name $32 filename $256 var $300;
  if "&inputfiles" ne "0" then do;
    webcount=countw("&inputfiles");
    do i=1 to webcount;
      var=scan("&inputfiles",i,' ');
      fileref=scan(var,1,':');
      name=scan(var,2,':');
      filename=cats(name,'.csv');
      output;
    end;
  end;
run;


/* execute the STP */
%let fref1=%mf_getuniquefileref();

%ms_runstp(&program
  ,debug=&debug
  ,inputparams=&inputparams
  ,inputfiles=&ds1
  ,outref=&fref1
  ,mdebug=&mdebug
  ,outlogds=&outlogds
)


/* chop out JSON section */
%local matchstr chopout;
%let matchstr=SASJS_LOGS_SEPARATOR_163ee17b6ff24f028928972d80a26784;
%let chopout=%sysfunc(pathname(work))/%mf_getuniquename(prefix=chop);

%mp_chop("%sysfunc(pathname(&fref1,F))"
  ,matchvar=matchstr
  ,keep=FIRST
  ,matchpoint=START
  ,offset=-1
  ,outfile="&chopout"
  ,mdebug=&mdebug
)

%if &outlib ne 0 %then %do;
  libname &outlib json "&chopout";
%end;
%if &outref ne 0 %then %do;
  filename &outref "&chopout";
%end;

%if &mdebug=0 %then %do;
  filename &webref clear;
  filename &fref1 clear;
%end;
%else %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;

%mend ms_testservice;
