/**
  @file
  @brief init file for tests

  <h4> SAS Macros </h4>
  @li mp_init.sas

**/

/* location in metadata or SAS Drive for temporary files */
%let mcTestAppLoc=/Public/temp/macrocore;

/* set defaults */
%mp_init()

%macro loglevel();
  %if &_debug=2477 %then %do;
    options mprint;
  %end;
%mend loglevel;

%loglevel()