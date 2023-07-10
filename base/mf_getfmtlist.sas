/**
  @file
  @brief Returns a distinct list of formats from a table
  @details Reads the dataset header and returns a distinct list of formats
  applied.

        %put NOTE- %mf_getfmtlist(sashelp.prdsale);
        %put NOTE- %mf_getfmtlist(sashelp.shoes);
        %put NOTE- %mf_getfmtlist(sashelp.demographics);

  returns:

      DOLLAR $CHAR W MONNAME
      $CHAR BEST DOLLAR
      BEST Z $CHAR COMMA PERCENTN

  @param [in] libds Two part library.dataset reference.

  <h4> SAS Macros </h4>
  @li mf_getfmtname.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getfmtlist(libds
)/*/STORE SOURCE*/;
/* declare local vars */
%local out dsid nvars x rc fmt;

/* open dataset in macro */
%let dsid=%sysfunc(open(&libds));

/* continue if dataset exists */
%if &dsid %then %do;
  /* loop each variable in the dataset */
  %let nvars=%sysfunc(attrn(&dsid,NVARS));
  %do x=1 %to &nvars;
    /* grab format and check it exists */
    %let fmt=%sysfunc(varfmt(&dsid,&x));
    %if %quote(&fmt) ne %quote() %then %let fmt=%mf_getfmtname(&fmt);
    %else %do;
      /* assign default format depending on variable type */
      %if %sysfunc(vartype(&dsid, &x))=C %then %let fmt=$CHAR;
      %else %let fmt=BEST;
    %end;
    /* concatenate unique list of formats */
    %if %sysfunc(indexw(&out,&fmt,%str( )))=0 %then %let out=&out &fmt;
  %end;
  %let rc=%sysfunc(close(&dsid));
%end;
%else %do;
  %put &sysmacroname: Unable to open &libds (rc=&dsid);
  %put &sysmacroname: SYSMSG= %sysfunc(sysmsg());
  %let rc=%sysfunc(close(&dsid));
%end;
/* send them out without spaces or quote markers */
%do;%unquote(&out)%end;
%mend mf_getfmtlist;