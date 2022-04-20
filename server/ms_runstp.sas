/**
  @file
  @brief Executes a SASjs Server Stored Program
  @details Runs a Stored Program (using POST method) and extracts the webout and
  log from the response JSON.

  Example:

      %ms_runstp(/some/stored/program
        ,debug=131
        ,outref=weboot
      )

  @param [in] pgm The full path to the Stored Program in SASjs Drive (_program
    parameter)
  @param [in] debug= (131) The value to supply to the _debug URL parameter
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [out] outref= (outweb) The output fileref to contain the response JSON
    (will be created using temp engine)

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mp_abort.sas

**/

%macro ms_runstp(pgm
    ,debug=131
    ,outref=outweb
    ,mdebug=0
  );
%local dbg fname1;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;
%let fname1=%mf_getuniquefileref();

%mp_abort(iftrue=("&pgm"="")
  ,mac=&sysmacroname
  ,msg=%str(Program not provided)
)

data _null_;
  file &fname1 lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  put 'Authorization: Bearer ' _infile_;
run;

filename &outref temp;

/* prepare request*/
proc http method='POST' headerin=&fname1 out=&outref
  url="&_sasjs_apiserverurl.&_sasjs_apipath?_program=&pgm%str(&)_debug=131";
run;
%if (&SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201)
  or &mdebug=1 %then %do;
  data _null_;infile &outref;input;putlog _infile_;run;
%end;
%mp_abort(
  iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)


%if &mdebug=1 %then %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;
%else %do;
  /* clear refs */
  filename &fname1 clear;
%end;
%mend ms_runstp;