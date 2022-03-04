/**
  @file
  @brief Returns an unused libref
  @details Use as follows:

    libname mclib0 (work);
    libname mclib1 (work);
    libname mclib2 (work);

    %let libref=%mf_getuniquelibref();
    %put &=libref;

  which returns:

> mclib3

  A blank value is returned if no usable libname is determined.

  @param prefix= first part of the returned libref. As librefs can be as long as
    8 characters, a maximum length of 7 characters is premitted for this prefix.
  @param maxtries= Deprecated parameter. Remains here to ensure a non-breaking
    change.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuniquelibref(prefix=mclib,maxtries=1000);
  %local x;

  %if ( %length(&prefix) gt 7 ) %then %do;
    %put NOTE: The prefix parameter cannot exceed 7 characters.;
    %return;
  %end;

  /* Set maxtries equal to '10 to the power of [# unused characters] - 1' */
  %let maxtries=%eval(10**(8-%length(&prefix))-1);

  %do x = 0 %to &maxtries;
    %if %sysfunc(libref(&prefix&x)) ne 0 %then %do;
      &prefix&x
      %return;
    %end;
    %let x = %eval(&x + 1);
  %end;

  %put NOTE: Unable to find a usable libref in the range &prefix.0-&maxtries..;
  %put NOTE: Change the prefix parameter.;
%mend mf_getuniquelibref;