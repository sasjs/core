/**
  @file
  @brief init file for tests

  <h4> SAS Macros </h4>
  @li mp_init.sas
  @li mv_webout.sas

**/

/* location in metadata or SAS Drive for temporary files */
%let mcTestAppLoc=/Public/temp/macrocore;

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
