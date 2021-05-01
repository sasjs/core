/**
  @file
  @brief Returns dataset variable list direct from header
  @details WAY faster than dictionary tables or sas views, and can
    also be called in macro logic (is pure macro). Can be used in open code,
    eg as follows:

        %put List of Variables=%mf_getvarlist(sashelp.class);

  returns:
  > List of Variables=Name Sex Age Height Weight

  For a seperated list of column values:

        %put %mf_getvarlist(sashelp.class,dlm=%str(,),quote=double);

  returns:
  > "Name","Sex","Age","Height","Weight"

  @param [in] libds Two part dataset (or view) reference.
  @param [in] dlm= ( ) Provide a delimiter (eg comma or space) to separate the
    variables
  @param [in] quote= (none) use either DOUBLE or SINGLE to quote the results

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getvarlist(libds
      ,dlm=%str( )
      ,quote=no
)/*/STORE SOURCE*/;
  /* declare local vars */
  %local outvar dsid nvars x rc dlm q var;

  /* credit Rowland Hale  - byte34 is double quote, 39 is single quote */
  %if %upcase(&quote)=DOUBLE %then %let q=%qsysfunc(byte(34));
  %else %if %upcase(&quote)=SINGLE %then %let q=%qsysfunc(byte(39));
  /* open dataset in macro */
  %let dsid=%sysfunc(open(&libds));


  %if &dsid %then %do;
    %let nvars=%sysfunc(attrn(&dsid,NVARS));
    %if &nvars>0 %then %do;
      /* add first dataset variable to global macro variable */
      %let outvar=&q.%sysfunc(varname(&dsid,1))&q.;
      /* add remaining variables with supplied delimeter */
      %do x=1 %to &nvars;
        %let var=&q.%sysfunc(varname(&dsid,&x))&q.;
        %if &var=&q&q %then %do;
          %put &sysmacroname: Empty column found in &libds!;
          %let var=&q. &q.;
        %end;
        %if &x=1 %then %let outvar=&var;
        %else %let outvar=&outvar.&dlm.&var.;
      %end;
    %end;
    %let rc=%sysfunc(close(&dsid));
  %end;
  %else %do;
    %put unable to open &libds (rc=&dsid);
    %let rc=%sysfunc(close(&dsid));
  %end;
  &outvar
%mend;