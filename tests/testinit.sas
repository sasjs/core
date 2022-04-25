/**
  @file
  @brief init file for tests

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_init.sas

**/

/* location in metadata or SAS Drive for temporary files */
%let mcTestAppLoc=/tmp/tests/sasjs/core/%mf_uid();

/* set defaults */
%mp_init()

%global _debug sasjs_mdebug;

%let sasjs_mdebug=0;

%macro loglevel();
  %if "&_debug"="2477" or "&_debug"="fields,log,trace" %then %do;
    %put debug mode activated;
    options mprint mprintnest;
    %let sasjs_mdebug=1;
  %end;
%mend loglevel;

%loglevel()

%put Initialised &_program;
%put _all_;
