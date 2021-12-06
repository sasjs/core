/**
  @file
  @brief Reset when an err condition occurs
  @details When building apps, sometimes an operation must be attempted that
  can cause an err condition.  There is no try catch in SAS! So the err state
  must be caught and reset.

  This macro attempts to do that reset.

  @version 9.2
  @author Allan Bowe

**/

%macro mp_reseterror(
)/*/STORE SOURCE*/;

options obs=max replace nosyntaxcheck;
%let syscc=0;

%if "&sysprocessmode " = "SAS Stored Process Server " %then %do;
  data _null_;
    rc=stpsrvset('program error', 0);
  run;
%end;

%mend mp_reseterror;