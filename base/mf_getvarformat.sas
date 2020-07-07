/**
  @file
  @brief Returns the format of a variable
  @details Uses varfmt function to identify the format of a particular variable.
  Usage:

      data test;
         format str1 $1.  num1 datetime19.;
         str2='hello mum!'; num2=666;
         stop;
      run;
      %put %mf_getVarFormat(test,str1);
      %put %mf_getVarFormat(work.test,num1);
      %put %mf_getVarFormat(test,str2,force=1);
      %put %mf_getVarFormat(work.test,num2,force=1);
      %put %mf_getVarFormat(test,renegade);

  returns:

      $1.
      DATETIME19.
      $10.
      8.
      NOTE: Variable renegade does not exist in test

  @param libds Two part dataset (or view) reference.
  @param var Variable name for which a format should be returned
  @param force Set to 1 to supply a default if the variable has no format
  @returns outputs format

  @author Allan Bowe
  @version 9.2
**/

%macro mf_getVarFormat(libds /* two level ds name */
      , var /* variable name from which to return the format */
      , force=0
)/*/STORE SOURCE*/;
  %local dsid vnum vformat rc vlen vtype;
  /* Open dataset */
  %let dsid = %sysfunc(open(&libds));
  %if &dsid > 0 %then %do;
    /* Get variable number */
    %let vnum = %sysfunc(varnum(&dsid, &var));
    /* Get variable format */
    %if(&vnum > 0) %then %let vformat=%sysfunc(varfmt(&dsid, &vnum));
    %else %do;
       %put NOTE: Variable &var does not exist in &libds;
       %let rc = %sysfunc(close(&dsid));
       %return;
    %end;
  %end;
  %else %do;
    %put dataset &libds not opened! (rc=&dsid);
    %return;
  %end;

  /* supply a default if no format available */
  %if %length(&vformat)<2 & &force=1 %then %do;
    %let vlen = %sysfunc(varlen(&dsid, &vnum));
    %let vtype = %sysfunc(vartype(&dsid, &vnum.));
    %if &vtype=C %then %let vformat=$&vlen..;
    %else %let vformat=8.;
  %end;


  /* Close dataset */
  %let rc = %sysfunc(close(&dsid));
  /* Return variable format */
  &vformat
%mend;