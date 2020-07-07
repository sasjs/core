/**
  @file
  @brief Returns variable type - Character (C) or Numeric (N)
  @details
Usage:

      data test;
         length str $1.  num 8.;
         stop;
      run;
      %put %mf_getvartype(test,str);
      %put %mf_getvartype(work.test,num);



  @param libds Two part dataset (or view) reference.
  @param var the variable name to be checked
  @return output returns C or N depending on variable type.  If variable
    does not exist then a blank is returned and a note is written to the log.

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getvartype(libds /* two level name */
      , var /* variable name from which to return the type */
)/*/STORE SOURCE*/;
  %local dsid vnum vtype rc;
  /* Open dataset */
  %let dsid = %sysfunc(open(&libds));
  %if &dsid. > 0 %then %do;
    /* Get variable number */
    %let vnum = %sysfunc(varnum(&dsid, &var));
    /* Get variable type (C/N) */
    %if(&vnum. > 0) %then %let vtype = %sysfunc(vartype(&dsid, &vnum.));
    %else %do;
       %put NOTE: Variable &var does not exist in &libds;
       %let vtype = %str( );
    %end;
  %end;
  %else %put dataset &libds not opened! (rc=&dsid);

  /* Close dataset */
  %let rc = %sysfunc(close(&dsid));
  /* Return variable type */
  &vtype
%mend;