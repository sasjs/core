/**
  @file
  @brief Checks if a set of variables ALL exist in a data set.
  @details Returns 0 if ANY of the variables do not exist, if the dataset
  cannot be opened, if it holds no variables, or if `libds` / `varlist` is
  blank.  Returns 1 if they ALL exist.  The macro never aborts: a blank input
  answers 0 and the calling program decides whether that is a condition to
  stop on (`mp_abort`) or simply a negative result.
  Usage:

      %put %mf_existVarList(sashelp.class, age sex name dummyvar);

  @param [in] libds 2 part dataset or view reference
  @param [in] varlist space separated variable names

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mf_existvarlist(libds, varlist
)/*/STORE SOURCE*/;

  /* nothing to check - answer 0 and let the caller decide whether a blank
    input is a condition worth stopping on */
  %if %str(&libds)=%str() or %str(&varlist)=%str() %then %do;
    %put %str(WARN)ING:  blank libds/varlist in mf_existvarlist;
    0
    %return;
  %end;

  %local dsid rc i var found;
  %let dsid=%sysfunc(open(&libds,is));

  %if &dsid=0 %then %do;
    %put %str(WARN)ING:  unable to open &libds in mf_existvarlist (&dsid);
    /* no member means none of the variables exist - and ATTRN / VARNUM
      return a missing value for dsid 0, so probing further would report
      a match */
    0
    %return;
  %end;

  %if %sysfunc(attrn(&dsid,NVARS))=0 %then %do;
    %put MF_EXISTVARLIST:  No variables in &libds ;
    %let rc=%sysfunc(close(&dsid));
    0
    %return;
  %end;

  %else %do i=1 %to %sysfunc(countw(&varlist));
    %let var=%scan(&varlist,&i);

    %if %sysfunc(varnum(&dsid,&var))=0  %then %do;
      %let found=&found &var;
    %end;
  %end;

  %let rc=%sysfunc(close(&dsid));
  %if %str(&found)=%str() %then %do;
    1
  %end;
  %else %do;
    0
    %put Vars not found: &found;
  %end;
%mend mf_existvarlist;

/** @endcond */
