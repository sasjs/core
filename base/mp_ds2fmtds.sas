/**
  @file
  @brief Converts every value in a dataset to formatted value
  @details Converts every value to it's formatted value.  All variables will
  become character, and will be in the same order as the original dataset.

  Lengths will be adjusted according to the format lengths, where applicable.

  Usage:

      %mp_ds2fmtds(sashelp.cars,work.cars)
      %mp_ds2fmtds(sashelp.vallopt,vw_vallopt)

  @param [in] libds The library.dataset to be converted
  @param [out] outds The dataset to create.

  <h4> SAS Macros </h4>
  @li mf_existds.sas

  <h4> Related Macros </h4>
  @li mp_jsonout.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mp_ds2fmtds(libds, outds
)/*/STORE SOURCE*/;

/* validations */

%if not %mf_existds(libds=&libds) %then %do;
  %put %str(WARN)ING:  &libds does not exist as either a VIEW or DATASET;
  %return;
%end;
%if %index(&libds,.)=0 %then %let libds=WORK.&libds;

/* grab metadata */
proc contents noprint data=&libds
  out=_data_(keep=name type length format formatl formatd varnum);
run;
proc sort;
  by varnum;
run;

/* prepare formats and varnames */
data _null_;
  set &syslast end=last;
  name=upcase(name);
  /* fix formats */
  if type=2 or type=6 then do;
    length fmt $49.;
    if format='' then fmt=cats('$',length,'.');
    else if formatl=0 then fmt=cats(format,'.');
    else fmt=cats(format,formatl,'.');
    newlen=max(formatl,length);
  end;
  else do;
    if format='' then fmt='best.';
    else if formatl=0 then fmt=cats(format,'.');
    else if formatd=0 then fmt=cats(format,formatl,'.');
    else fmt=cats(format,formatl,'.',formatd);
    /* needs to be wide, for datetimes etc */
    newlen=max(length,formatl,24);
  end;
  /* 32 char unique name */
  newname='sasjs'!!substr(cats(put(md5(name),$hex32.)),1,27);

  call symputx(cats('name',_n_),name,'l');
  call symputx(cats('newname',_n_),newname,'l');
  call symputx(cats('len',_n_),newlen,'l');
  call symputx(cats('fmt',_n_),fmt,'l');
  call symputx(cats('type',_n_),type,'l');
  if last then call symputx('nobs',_n_,'l');
run;

/* clean up */
proc sql;
drop table &syslast;

%if &nobs=0 %then %do;
  %put Dataset &libds has no columns!
  data &outds;
    set &libds;
  run;
  %return;
%end;

data &outds;
  /* rename on entry */
  set &libds(rename=(
%local i;
%do i=1 %to &nobs;
  &&name&i=&&newname&i
%end;
  ));
%do i=1 %to &nobs;
  length &&name&i $&&len&i;
  &&name&i=left(put(&&newname&i,&&fmt&i));
  drop &&newname&i;
%end;
  if _error_ then call symputx('syscc',1012);
run;

%mend mp_ds2fmtds;