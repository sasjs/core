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

  @param [in] prefix= (mclib) first part of the returned libref. As librefs can
    be as long as 8 characters, a maximum length of 7 characters is premitted
    for this prefix.
  @param [in] maxtries= Deprecated parameter. Remains here to ensure a
    non-breaking change.  Will be removed in v5.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuniquelibref(prefix=mclib,maxtries=1000);
  %local x;

  %if ( %length(&prefix) gt 7 ) %then %do;
    %put %str(ERR)OR: The prefix parameter cannot exceed 7 characters.;
    0
    %return;
  %end;
  %else %if (%sysfunc(NVALID(&prefix,v7))=0) %then %do;
    %put %str(ERR)OR: Invalid prefix (&prefix);
    0
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

  %put %str(ERR)OR: No usable libref in range &prefix.0-&maxtries;
  %put %str(ERR)OR- Try reducing the prefix or deleting some libraries!;
  0
%mend mf_getuniquelibref;