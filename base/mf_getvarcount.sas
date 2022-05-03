/**
  @file
  @brief Returns number of variables in a dataset
  @details Useful to identify those renagade datasets that have no columns!
  Can also be used to count for numeric, or character columns

      %put Number of Variables=%mf_getvarcount(sashelp.class);
      %put Character Variables=%mf_getvarcount(sashelp.class,typefilter=C);
      %put Numeric Variables = %mf_getvarcount(sashelp.class,typefilter=N);

  returns:
  > Number of Variables=4


  @param [in] libds Two part dataset (or view) reference.
  @param [in] typefilter= (A) Filter for certain types of column.  Valid values:
    @li A Count All columns
    @li C Count Character columns only
    @li N Count Numeric columns only

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getvarcount(libds,typefilter=A
)/*/STORE SOURCE*/;
  %local dsid nvars rc outcnt x;
  %let dsid=%sysfunc(open(&libds));
  %let nvars=.;
  %let outcnt=0;
  %let typefilter=%upcase(&typefilter);
  %if &dsid %then %do;
    %let nvars=%sysfunc(attrn(&dsid,NVARS));
    %if &typefilter=A %then %let outcnt=&nvars;
    %else %if &nvars>0 %then %do x=1 %to &nvars;
      /* increment based on variable type */
      %if %sysfunc(vartype(&dsid,&x))=&typefilter %then %do;
        %let outcnt=%eval(&outcnt+1);
      %end;
    %end;
    %let rc=%sysfunc(close(&dsid));
  %end;
  %else %do;
    %put unable to open &libds (rc=&dsid);
    %let rc=%sysfunc(close(&dsid));
  %end;
  &outcnt
%mend mf_getvarcount;