/**
  @file
  @brief Returns number of variables in a dataset
  @details Useful to identify those renagade datasets that have no columns!

        %put Number of Variables=%mf_getvarcount(sashelp.class);

  returns:
  > Number of Variables=4

  @param libds Two part dataset (or view) reference.

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getvarcount(libds
)/*/STORE SOURCE*/;
  %local dsid nvars rc ;
  %let dsid=%sysfunc(open(&libds));
  %let nvars=.;
  %if &dsid %then %do;
    %let nvars=%sysfunc(attrn(&dsid,NVARS));
    %let rc=%sysfunc(close(&dsid));
  %end;
  %else %do;
    %put unable to open &libds (rc=&dsid);
    %let rc=%sysfunc(close(&dsid));
  %end;
  &nvars
%mend;