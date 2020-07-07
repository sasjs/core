/**
  @file
  @brief Returns the length of a variable
  @details Uses varlen function to identify the length of a particular variable.
  Usage:

      data test;
         format str $1.  num datetime19.;
         stop;
      run;
      %put %mf_getVarLen(test,str);
      %put %mf_getVarLen(work.test,num);
      %put %mf_getVarLen(test,renegade);

  returns:

      1
      8
      NOTE: Variable renegade does not exist in test

  @param libds Two part dataset (or view) reference.
  @param var Variable name for which a length should be returned
  @returns outputs length

  @author Allan Bowe
  @version 9.2

**/

%macro mf_getVarLen(libds /* two level ds name */
      , var /* variable name from which to return the length */
)/*/STORE SOURCE*/;
  %local dsid vnum vlen rc;
  /* Open dataset */
  %let dsid = %sysfunc(open(&libds));
  %if &dsid > 0 %then %do;
    /* Get variable number */
    %let vnum = %sysfunc(varnum(&dsid, &var));
    /* Get variable format */
    %if(&vnum > 0) %then %let vlen = %sysfunc(varlen(&dsid, &vnum));
    %else %do;
       %put NOTE: Variable &var does not exist in &libds;
       %let vlen = %str( );
    %end;
  %end;
  %else %put dataset &libds not opened! (rc=&dsid);

  /* Close dataset */
  %let rc = %sysfunc(close(&dsid));
  /* Return variable format */
  &vlen
%mend;