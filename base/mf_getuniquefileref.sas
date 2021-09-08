/**
  @file
  @brief Assigns and returns an unused fileref
  @details
  Use as follows:

      %let fileref1=%mf_getuniquefileref();
      %let fileref2=%mf_getuniquefileref();
      %put &fileref1 &fileref2;

  which returns something similar to:

> #LN01295 #LN01297

  A previous version of this macro worked by assigning sequential filerefs.
  The current version uses the native "find a unique fileref" functionality
  within the filename function, which is 100 times faster.

  @param prefix= Deprecated.  Will be removed in a future release.
  @param maxtries= Deprecated. Will be removed in a future release.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuniquefileref(prefix=0,maxtries=1000);
  %local rc fname;
  %if &prefix=0 %then %do;
    %let rc=%sysfunc(filename(fname,,temp));
    %if &rc %then %put %sysfunc(sysmsg());
    &fname
  %end;
  %else %do;
    %local x;
    %let x=0;
    %do x=0 %to &maxtries;
    %if %sysfunc(fileref(&prefix&x)) > 0 %then %do;
      %let fname=&prefix&x;
      %let rc=%sysfunc(filename(fname,,temp));
      %if &rc %then %put %sysfunc(sysmsg());
      &prefix&x
      %return;
    %end;
    %end;
    %put unable to find available fileref in range &prefix.0-&maxtries;
  %end;
%mend mf_getuniquefileref;