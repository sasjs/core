/**
  @file
  @brief Export a dataset to SQL insert statements
  @details Converts dataset values to SQL insert statements for use across
  multiple database types.

  Usage:

      %mp_ds2inserts(sashelp.class,outref=myref)
      data test;
        set sashelp.class;
        stop;
      proc sql;
      %inc myref;

  @param [in] ds The dataset to be exported
  @param [out] outref= (0) The output fileref.  If it does not exist, it is
    created. If it does exist, new records are APPENDED.
  @param [out] outlib= (0) The library (or schema) in which the target table is
    located.  If not provided, is ignored.
  @param [out] outds= (0) The output table to load.  If not provided, will
    default to the table in the &ds parameter.

  <h4> SAS Macros </h4>
  @li mf_existfileref.sas
  @li mf_getvarcount.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas

  @version 9.2
  @author Allan Bowe (credit mjsq)
**/

%macro mp_ds2inserts(ds, outref=0,outlib=0,outds=0
)/*/STORE SOURCE*/;

%if not %sysfunc(exist(&ds)) %then %do;
  %put %str(WARN)ING:  &ds does not exist;
  %return;
%end;

%if %index(&ds,.)=0 %then %let ds=WORK.&ds;

%if &outref=0 %then %do;
  %put %str(WARN)ING:  Please provide a fileref;
  %return;
%end;
%if %mf_existfileref(&outref)=0 %then %do;
  filename &outref temp lrecl=66000;
%end;

%if &outlib=0 %then %let outlib=;
%else %let outlib=&outlib..;

%if &outds=0 %then %let outds=%scan(&ds,2,.);

%local nobs;
proc sql noprint;
select count(*) into: nobs TRIMMED from &ds;
%if &nobs=0 %then %do;
  data _null_;
    file &outref mod;
    put "/* No rows found in &ds */";
  run;
%end;

%local vars;
%let vars=%mf_getvarcount(&ds);
%if &vars=0 %then %do;
  data _null_;
    file &outref mod;
    put "/* No columns found in &ds */";
  run;
%end;

%local varlist;
%let varlist=%mf_getvarlist(&ds);

proc format; /* credit yabwon for special null removal */
  value bart ._ - .z = null
  other = [best.];
/* next, export data */
data _null_;
  file &outref mod ;
  if _n_=1 then put "/* &outlib..&outds (&nobs rows, &vars columns) */";
  set &ds;
  length _____str $32767;
  format _numeric_ best.;
  format _character_ ;
  %local i comma var vtype;
  %do i=1 %to %sysfunc(countw(&varlist));
    %let var=%scan(&varlist,&i);
    %let vtype=%mf_getvartype(&ds,&var);
    %if &i=1 %then %do;
      put "insert into &outlib.&outds set ";
      put "  &var="@;
    %end;
    %else %do;
      put "  ,&var="@;
    %end;
    %if &vtype=N %then %do;
      /* @todo - deal with nulls in other db flavours */
      /* from ._ to .z */
      put &var;
    %end;
    %else %do;
      _____str="'"!!trim(tranwrd(&var,"'","''"))!!"'";
      put _____str;
    %end;
  %end;
  put ';';
  if _n_=&nobs then put /;
run;

%mend mp_ds2inserts;