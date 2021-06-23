/**
  @file
  @brief Assigns and returns an unused fileref
  @details
  Use as follows:

      %let fileref1=%mf_getuniquefileref();
      %let fileref2=%mf_getuniquefileref();
      %put &fileref1 &fileref2;

  which returns:

> mcref0 mcref1

  @param prefix= first part of fileref. Remember that filerefs can only be 8
    characters, so a 7 letter prefix would mean that `maxtries` should be 10.
  @param maxtries= the last part of the libref.  Provide an integer value.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuniquefileref(prefix=mcref,maxtries=1000);
  %local x fname;
  %let x=0;
  %do x=0 %to &maxtries;
  %if %sysfunc(fileref(&prefix&x)) > 0 %then %do;
    %let fname=&prefix&x;
    %let rc=%sysfunc(filename(fname,,temp));
    %if &rc %then %put %sysfunc(sysmsg());
    &prefix&x
    %*put &sysmacroname: Fileref &prefix&x was assigned and returned;
    %return;
  %end;
  %end;
  %put unable to find available fileref in range &prefix.0-&maxtries;
%mend mf_getuniquefileref;