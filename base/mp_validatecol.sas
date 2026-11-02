/**
  @file
  @brief Used to validate values in a data step
  @details Useful when sanitising inputs, to ensure that they arrive with a
  certain pattern.
  Usage:

      data test;
        infile datalines4 dsd;
        input;
        libds=_infile_;
        %mp_validatecol(libds,LIBDS,is_libds)
      datalines4;
      some.libname
      !lib.blah
      %abort
      definite.ok
      not.ok!
      nineletrs._
      ;;;;
      run;

  For more examples, see mp_validatecol.test.sas

  Tip - when contributing, use https://regex101.com to test the regex validity!

  @param [in] incol The column to be validated
  @param [in] rule The rule to apply.  Current rules:
    @li ISINT - checks if the variable is an integer
    @li ISLIB - checks if the value is a valid libref (NOT whether it exists)
    @li ISNAME - checks if the value is a valid SAS NAME (V7 rules - up to 32
      chars, starting with a letter or underscore, followed by letters,
      numbers or underscores)
    @li ISNUM - checks if the variable is numeric
    @li LIBDS - matches LIBREF.DATASET format
    @li FORMAT - checks if the provided format is syntactically valid
    @li ISPATH - checks that the value is an absolute path this platform would
      accept.  Shape only - whether the path exists is a different question
      (mf_isdir / fileexist)
  @param [out] outcol The variable to create, with the results of the match

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas

  <h4> Related Macros </h4>
  @li mp_validatecol.test.sas

  @version 9.3
**/

%macro mp_validatecol(incol,rule,outcol);

/* tempcol is given a unique name with every invocation */
%local tempcol;
%let tempcol=%mf_getuniquename();

%if &rule=ISINT %then %do;
  &outcol=0;
  if not missing(&incol) then do;
    &tempcol=input(&incol,?? best32.);
    if not missing(&tempcol) then if mod(&tempcol,1)=0 then &outcol=1;
  end;
  drop &tempcol;
%end;
%else %if &rule=ISNUM %then %do;
  /*
    credit SOREN LASSEN
    https://sasmacro.blogspot.com/2009/06/welcome-isnum-macro.html
  */
  &tempcol=input(&incol,?? best32.);
  if missing(&tempcol) then &outcol=0;
  else &outcol=1;
  drop &tempcol;
%end;
%else %if &rule=ISLIB %then %do;
  if _n_=1 then do;
    retain &tempcol;
    &tempcol=prxparse('/^[_a-z]\w{0,7}$/i');
    if missing(&tempcol) then do;
      putlog 'ERR' +(-1) "OR: Invalid expression for ISLIB";
      stop;
    end;
    drop &tempcol;
  end;
  if prxmatch(&tempcol, trim(&incol)) then &outcol=1;
  else &outcol=0;
%end;
%else %if &rule=ISNAME %then %do;
  /* match a valid SAS name (V7 rules) */
  if _n_=1 then do;
    retain &tempcol;
    &tempcol=prxparse('/^[_a-z]\w{0,31}$/i');
    if missing(&tempcol) then do;
      putlog 'ERR' +(-1) "OR: Invalid expression for ISNAME";
      stop;
    end;
    drop &tempcol;
  end;
  if prxmatch(&tempcol, trim(&incol)) then &outcol=1;
  else &outcol=0;
%end;
%else %if &rule=LIBDS %then %do;
  /* match libref.dataset */
  if _n_=1 then do;
    retain &tempcol;
    &tempcol=prxparse('/^[_a-z]\w{0,7}\.[_a-z]\w{0,31}$/i');
    if missing(&tempcol) then do;
      putlog 'ERR' +(-1) "OR: Invalid expression for LIBDS";
      stop;
    end;
    drop &tempcol;
  end;
  if prxmatch(&tempcol, trim(&incol)) then &outcol=1;
  else &outcol=0;
%end;
%else %if &rule=ISPATH %then %do;
  /*
    An absolute path on the current platform.  This is a shape check: a path
    that passes may still not exist, and one that fails would be rejected by
    the operating system rather than read as a folder.
  */
  &outcol=0;
  if length(trim(&incol))>0 and anycntrl(&incol)=0 then do;
    %if "%upcase(&sysscp)"="WIN" or "%upcase(&sysscp)"="DNTHOST" %then %do;
      /* a drive root (C:/folder) */
      if substr(&incol,2,1)=':' and substr(&incol,3,1) in ('\','/') then
        &outcol=1;
      /* a UNC share needs both a host and a share - \\host\ is not openable */
      if substr(&incol,1,2)='\\' and scan(&incol,2,'\') ne '' then
        &outcol=1;
      /* characters windows does not accept in a name, and a colon
        anywhere but the drive separator */
      if &outcol=1 then do;
        if index(substr(&incol,3),':')>0 then &outcol=0;
        if index(&incol,byte(34))>0 then &outcol=0;
        if index(&incol,'<')>0 then &outcol=0;
        if index(&incol,'>')>0 then &outcol=0;
        if index(&incol,'|')>0 then &outcol=0;
        if index(&incol,'?')>0 then &outcol=0;
        if index(&incol,'*')>0 then &outcol=0;
      end;
    %end;
    %else %do;
      if substr(&incol,1,1)='/' then &outcol=1;
    %end;
  end;
%end;
%else %if &rule=FORMAT %then %do;
  /* match valid SAS format*/
  if _n_=1 then do;
    retain &tempcol;
    &tempcol=prxparse('/^(?:[_a-z\$]\w{0,31}|[0-9]+)\.[0-9]*$/i');
    if missing(&tempcol) then do;
      putlog 'ERR' +(-1) "OR: Invalid expression for FORMAT";
      stop;
    end;
    drop &tempcol;
  end;
  if prxmatch(&tempcol, trim(&incol)) then &outcol=1;
  else &outcol=0;
%end;

%mend mp_validatecol;
