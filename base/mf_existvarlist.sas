/**
  @file
  @brief Checks if a set of variables ALL exist in a data set.
  @details Returns 0 if ANY of the variables do not exist, or 1 if they ALL do.
    Usage:

        %put %mf_existVarList(sashelp.class, age sex name dummyvar)

  <h4> Dependencies </h4>
  @li mf_abort.sas

  @param libds 2 part dataset or view reference
  @param varlist space separated variable names

  @version 9.2
  @author Allan Bowe
**/

%macro mf_existvarlist(libds, varlist
)/*/STORE SOURCE*/;

  %if %str(&libds)=%str() or %str(&varlist)=%str() %then %do;
    %mf_abort(msg=No value provided to libds(&libds) or varlist (&varlist)!
      ,mac=mf_existvarlist.sas)
  %end;

  %local dsid rc i var found;
  %let dsid=%sysfunc(open(&libds,is));

  %if &dsid=0 %then %do;
    %put WARNING:  unable to open &libds in mf_existvarlist (&dsid);
  %end;

  %if %sysfunc(attrn(&dsid,NVARS))=0 %then %do;
    %put MF_EXISTVARLIST:  No variables in &libds ;
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
%mend;