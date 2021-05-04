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

  @param [in] incol The column to be validated
  @param [in] rule The rule to apply.  Current rules:
    @li LIBDS - matches LIBREF.DATASET format
  @param [out] outcol The variable to create, with the results of the match

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas

  @version 9.3
**/

%macro mp_validatecol(incol,rule,outcol);

/* tempcol is given a unique name with every invocation */
%local tempcol;
%let tempcol=%mf_getuniquename();

%if &rule=ISNUM %then %do;
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

%mend;
