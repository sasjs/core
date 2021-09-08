/**
  @file
  @brief Assigns and returns an unused fileref
  @details  Using the native approach for assigning filerefs fails as some
  procedures (such as proc http) do not recognise the temporary names (starting
  with a hash), returning a message such as:

  > ERROR 22-322: Expecting a name.

  This macro works by attempting a random fileref (with a prefix), seeing if it
  is already assigned, and if not - returning the fileref.

  If your process can accept filerefs with the hash (#) prefix, then set
  `prefix=0` to revert to the native approach - which is significantly faster
  when there are a lot of filerefs in a session.

  Use as follows:

      %let fileref1=%mf_getuniquefileref();
      %let fileref2=%mf_getuniquefileref(prefix=0);
      %put &fileref1 &fileref2;

  which returns filerefs similar to:

> _7432233 #LN00070

  @param [in] prefix= (_) first part of fileref. Remember that filerefs can only
    be 8 characters, so a 7 letter prefix would mean `maxtries` should be 10.
    if using zero (0) as the prefix, a native assignment is used.
  @param [in] maxtries= (1000) the last part of the libref. Must be an integer.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuniquefileref(prefix=_,maxtries=1000);
  %local rc fname;
  %if &prefix=0 %then %do;
    %let rc=%sysfunc(filename(fname,,temp));
    %if &rc %then %put %sysfunc(sysmsg());
    &fname
  %end;
  %else %do;
    %local x len;
    %let len=%eval(8-%length(&prefix));
    %let x=0;
    %do x=0 %to &maxtries;
      %let fname=&prefix%substr(%sysfunc(ranuni(0)),3,&len);
      %if %sysfunc(fileref(&fname)) > 0 %then %do;
        %let rc=%sysfunc(filename(fname,,temp));
        %if &rc %then %put %sysfunc(sysmsg());
        &fname
        %return;
      %end;
    %end;
    %put unable to find available fileref after &maxtries attempts;
  %end;
%mend mf_getuniquefileref;