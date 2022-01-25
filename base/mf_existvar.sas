/**
  @file
  @brief Checks if a variable exists in a data set.
  @details Returns 0 if the variable does NOT exist, and the position of the var
  if it does.
  Usage:

      %put %mf_existvar(work.someds, somevar)

  @param [in] libds 2 part dataset or view reference
  @param [in] var variable name

  <h4> Related Macros </h4>
  @li mf_existvar.test.sas

  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mf_existvar(libds /* 2 part dataset name */
      , var /* variable name */
)/*/STORE SOURCE*/;

  %local dsid rc;
  %let dsid=%sysfunc(open(&libds,is));

  %if &dsid=0 or %length(&var)=0 %then %do;
    %put %sysfunc(sysmsg());
      0
  %end;
  %else %do;
      %sysfunc(varnum(&dsid,&var))
      %let rc=%sysfunc(close(&dsid));
  %end;

%mend mf_existvar;

/** @endcond */