/**
  @file mp_getmaxvarlengths.sas
  @brief Scans a dataset to find the max length of the variable values
  @details  
  This macro will scan a base dataset and produce an output dataset with two
  columns:

  - NAME    Name of the base dataset column
  - MAXLEN Maximum length of the data contained therein.

  Character fields may be allocated very large widths (eg 32000) of which the maximum
    value is likely to be much narrower.  This macro was designed to enable a HTML
    table to be appropriately sized however this could be used as part of a data
    audit to ensure we aren't over-sizing our tables in relation to the data therein.

  Numeric fields are converted using the relevant format to determine the width.
  Usage:

      %mp_getmaxvarlengths(sashelp.class,outds=work.myds)

  @param libds Two part dataset (or view) reference.
  @param outds= The output dataset to create

  <h4> SAS Macros </h4>
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_getvarformat.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getmaxvarlengths(
    libds      /* libref.dataset to analyse */
   ,outds=work.mp_getmaxvarlengths /* name of output dataset to create */
)/*/STORE SOURCE*/;

%local vars x var fmt;
%let vars=%mf_getvarlist(libds=&libds);

proc sql;
create table &outds (rename=(
    %do x=1 %to %sysfunc(countw(&vars,%str( )));
      ________&x=%scan(&vars,&x)
    %end;
    ))
  as select
    %do x=1 %to %sysfunc(countw(&vars,%str( )));
      %let var=%scan(&vars,&x);
      %if &x>1 %then ,;
      %if %mf_getvartype(&libds,&var)=C %then %do;
        max(length(&var)) as ________&x
      %end;
      %else %do;
        %let fmt=%mf_getvarformat(&libds,&var);
        %put fmt=&fmt;
        %if %str(&fmt)=%str() %then %do;
          max(length(cats(&var))) as ________&x
        %end;
        %else %do;
          max(length(put(&var,&fmt))) as ________&x
        %end;
      %end;
    %end;
  from &libds;

  proc transpose data=&outds
    out=&outds(rename=(_name_=NAME COL1=MAXLEN));
  run;

%mend;