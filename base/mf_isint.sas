/**
  @file
  @brief Returns 1 if the variable contains only digits 0-9, else 0
  @details Note that numerics containing any punctuation (including decimals
    or exponents) will be flagged zero.

  If you'd like support for this, then do raise an issue (or even better, a
  pull request!)

  Usage:

      %put %mf_isint(1) returns 1;
      %put %mf_isint(1.1) returns 0;
      %put %mf_isint(%str(1,1)) returns 0;

  @param [in] arg input value to check

  @version 9.2
**/

%macro mf_isint(arg
)/*/STORE SOURCE*/;

  /* blank val is not an integer */
  %if "&arg"="" %then %do;0%return;%end;

  /* remove minus sign if exists */
  %local val;
  %if "%substr(%str(&arg),1,1)"="-" %then %let val=%substr(%str(&arg),2);
  %else %let val=&arg;

  /* check remaining chars */
  %if %sysfunc(findc(%str(&val),,kd)) %then %do;0%end;
  %else %do;1%end;

%mend mf_isint;
