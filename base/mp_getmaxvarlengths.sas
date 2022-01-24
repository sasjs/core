/**
  @file
  @brief Scans a dataset to find the max length of the variable values
  @details
  This macro will scan a base dataset and produce an output dataset with two
  columns:

  - NAME    Name of the base dataset column
  - MAXLEN  Maximum length of the data contained therein.

  Character fields are often allocated very large widths (eg 32000) of which the
  maximum  value is likely to be much narrower.  Identifying such cases can be
  helpful in the following scenarios:

  @li Enabling a HTML table to be appropriately sized (`num2char=YES`)
  @li Reducing the size of a dataset to save on storage (mp_ds2squeeze.sas)
  @li Identifying columns containing nothing but missing values (`MAXLEN=0` in
    the output table)

  If the entire column is made up of (non-special) missing values then a value
  of 0 is returned.

  Usage:

      %mp_getmaxvarlengths(sashelp.class,outds=work.myds)

  @param [in] libds Two part dataset (or view) reference.
  @param [in] num2char= (NO) When set to NO, numeric fields are sized according
    to the number of bytes used (or set to zero in the case of non-special
    missings). When YES, the numeric field is converted to character (using the
    format, if available), and that is sized instead, using `lengthn()`.
  @param [out] outds= The output dataset to create, eg:
  |NAME:$8.|MAXLEN:best.|
  |---|---|
  |`Name `|`7 `|
  |`Sex `|`1 `|
  |`Age `|`3 `|
  |`Height `|`8 `|
  |`Weight `|`3 `|

  <h4> SAS Macros </h4>
  @li mcf_length.sas
  @li mf_getuniquename.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_getvarformat.sas

  @version 9.2
  @author Allan Bowe

  <h4> Related Macros </h4>
  @li mp_ds2squeeze.sas
  @li mp_getmaxvarlengths.test.sas

**/

%macro mp_getmaxvarlengths(
  libds
  ,num2char=NO
  ,outds=work.mp_getmaxvarlengths
)/*/STORE SOURCE*/;

%local vars prefix x var fmt;
%let vars=%mf_getvarlist(libds=&libds);
%let prefix=%substr(%mf_getuniquename(),1,25);
%let num2char=%upcase(&num2char);

%if &num2char=NO %then %do;
  /* compile length function for numeric fields */
  %mcf_length(wrap=YES, insert_cmplib=YES)
%end;

proc sql;
create table &outds (rename=(
    %do x=1 %to %sysfunc(countw(&vars,%str( )));
      &prefix.&x=%scan(&vars,&x)
    %end;
    ))
  as select
    %do x=1 %to %sysfunc(countw(&vars,%str( )));
      %let var=%scan(&vars,&x);
      %if &x>1 %then ,;
      %if %mf_getvartype(&libds,&var)=C %then %do;
        max(lengthn(&var)) as &prefix.&x
      %end;
      %else %if &num2char=YES %then %do;
        %let fmt=%mf_getvarformat(&libds,&var);
        %put fmt=&fmt;
        %if %str(&fmt)=%str() %then %do;
          max(lengthn(cats(&var))) as &prefix.&x
        %end;
        %else %do;
          max(lengthn(put(&var,&fmt))) as &prefix.&x
        %end;
      %end;
      %else %do;
        max(mcf_length(&var)) as &prefix.&x
      %end;
    %end;
  from &libds;

  proc transpose data=&outds
    out=&outds(rename=(_name_=NAME COL1=MAXLEN));
  run;

%mend mp_getmaxvarlengths;