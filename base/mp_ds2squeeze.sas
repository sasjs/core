/**
  @file
  @brief Create a smaller version of a dataset, without data loss
  @details This macro will scan the input dataset and create a new one, that
  has the minimum variable lengths needed to store the data without data loss.

  Inspiration was taken from [How to Reduce the Disk Space Required by a
  SAS® Data Set](https://www.lexjansen.com/nesug/nesug06/io/io18.pdf) by
  Selvaratnam Sridharma.  The end of the referenced paper presents a macro named
  "squeeze", hence the nomenclature.

  Usage:

      data big;
        length my big $32000;
        do i=1 to 1e4;
          my=repeat('oh my',100);
          big='dawg';
          special=._;
          output;
        end;
      run;

      %mp_ds2squeeze(work.big,outds=work.smaller)

  The following will also be printed to the log (exact values may differ
  depending on your OS and COMPRESS settings):

  > MP_DS2SQUEEZE: work.big was  625MB

  > MP_DS2SQUEEZE: work.smaller is    5MB

  @param [in] libds The library.dataset to be squeezed
  @param [out] outds= (work.mp_ds2squeeze) The squeezed dataset to create
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_getfilesize.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mp_getmaxvarlengths.sas

  <h4> Related Programs </h4>
  @li mp_ds2squeeze.test.sas

  @version 9.3
  @author Allan Bowe
**/

%macro mp_ds2squeeze(
  libds,
  outds=work.work.mp_ds2squeeze,
  mdebug=0
)/*/STORE SOURCE*/;
%local dbg source;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %do;
  %let dbg=*;
  %let source=/source2;
%end;

%local optval ds fref;
%let ds=%mf_getuniquename();
%let fref=%mf_getuniquefileref();

%mp_getmaxvarlengths(&libds,outds=&ds)

data _null_;
  set &ds end=last;
  file &fref;
  /* grab the types */
  retain dsid;
  if _n_=1 then dsid=open("&libds",'is');
  if dsid le 0 then do;
    msg=sysmsg();
    put msg=;
    stop;
  end;
  type=vartype(dsid,varnum(dsid, name));
  if last then rc=close(dsid);
  /* write out the length statement */
  if _n_=1 then put 'length ';
  length len $6;
  if type='C' then do;
    if maxlen=0 then len='$1';
    else len=cats('$',maxlen);
  end;
  else do;
    if maxlen=0 then len='3';
    else len=cats(maxlen);
  end;
  put '  ' name ' ' len;
  if last then put ';';
run;

/* configure varlenchk - as we are explicitly shortening the variables */
%let optval=%sysfunc(getoption(varlenchk));
options varlenchk=NOWARN;

data &outds;
  %inc &fref &source;
  set &libds;
run;

options varlenchk=&optval;

%if &mdebug=0 %then %do;
  proc sql;
  drop table &ds;
  filename &fref clear;
%end;

%put &sysmacroname: &libds was %mf_getfilesize(libds=&libds,format=yes);
%put &sysmacroname: &outds is %mf_getfilesize(libds=&outds,format=yes);

%mend mp_ds2squeeze;