/**
  @file
  @brief init file for tests

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_init.sas
  @li ms_webout.sas

**/

/* location in metadata or SAS Drive for temporary files */
%let mcTestAppLoc=/Users/&sysuserid/testresults/sasjs_core/%mf_uid();

/**
  * Use the context the test session is actually running in (passed by the
  * CLI as _contextName on the test URL) when available, else fall back to
  * the historical default.  This lets job-spawning tests create child
  * jobs in the same context on servers that do not have the default
  * context (e.g. a reusable context on a Viya demo tenant).
  * A data step is used (rather than open code %if) because nested
  * open code %if statements are not supported on all platforms.
  */
%let mcTestContext=SAS Job Execution compute context;
data _null_;
  if symexist('_contextname') then do;
    length ctx $256;
    ctx=cats(symget('_contextname'));
    if ctx ne '' then call symputx('mcTestContext',ctx,'g');
  end;
run;

/* set defaults */
%mp_init()

options lrecl=80;

%global _debug sasjs_mdebug;

%let sasjs_mdebug=0;

%macro loglevel();
  %if "&_debug"="2477" or "&_debug"="fields,log,trace" or "&_debug"="131"
  or "&_debug"="128"
  %then %do;
    %put debug mode activated;
    options mprint mprintnest;
    %let sasjs_mdebug=1;
  %end;
%mend loglevel;

%loglevel()

%put Initialised &_program;
%put _all_;
