/**
  @file
  @brief init file for tests

**/

/* location in metadata or SAS Drive for temporary files */
%let mcTestAppLoc=/Public/temp/macrocore;

%macro loglevel();
  %if &_debug=2477 %then %do;
    options mprint;
  %end;
%mend loglevel;

%loglevel()