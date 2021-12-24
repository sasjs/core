/**
  @file
  @brief Used to validate variables in a dataset
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
    @li ISNUM - checks if the variable is numeric
    @li LIBDS - matches LIBREF.DATASET format
    @li FORMAT - checks if the provided format is syntactically valid
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
  &tempcol=input(&incol,?? best32.);
  &outcol=0;
  if not missing(&tempcol) then if mod(&incol,1)=0 then &outcol=1;
  drop &tempcol;
%end;
%else %if &rule=ISNUM %then %do;
  /*
    credit SØREN LASSEN
    https://sasmacro.blogspot.com/2009/06/welcome-isnum-macro.html
  */
  &tempcol=input(&incol,?? best32.);
  if missing(&tempcol) then &outcol=0;
  else &outcol=1;
  drop &tempcol;
%end;
%else %if &rule=LIBDS %then %do;
  /* match libref.dataset */
  if _n_=1 then do;
    retain &tempcol;
    &tempcol=prxparse('/^[_a-z]\w{0,7}\.[_a-z]\w{0,31}$/i');
    if missing(&tempcol) then do;
      putlog "%str(ERR)OR: Invalid expression for LIBDS";
      stop;
    end;
    drop &tempcol;
  end;
  if prxmatch(&tempcol, trim(&incol)) then &outcol=1;
  else &outcol=0;
%end;
%else %if &rule=FORMAT %then %do;
  /* match valid format - regex could probably be improved */
  if _n_=1 then do;
    retain &tempcol;
    &tempcol=prxparse('/^[_a-z\$]\w{0,31}\.[0-9]*$/i');
    if missing(&tempcol) then do;
      putlog "%str(ERR)OR: Invalid expression for FORMAT";
      stop;
    end;
    drop &tempcol;
  end;
  if prxmatch(&tempcol, trim(&incol)) then &outcol=1;
  else &outcol=0;
%end;

%mend mp_validatecol;
