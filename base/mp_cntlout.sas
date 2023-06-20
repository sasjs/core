/**
  @file mp_cntlout.sas
  @brief Creates a cntlout dataset in a consistent format
  @details The dataset produced by proc format in the cntlout option will vary
  according to its contents.

  When dealing with formats from an ETL perspective (eg in [Data Controller for
  SAS](https://datacontroller.io)), it is important that the output dataset
  has a consistent model (and compariable values).

  This macro makes use of mddl_sas_cntlout.sas to provide the consistent model,
  and will left-align the start and end values when dealing with numeric ranges
  to enable consistency when checking for differences.

  usage:

      %mp_cntlout(libcat=yourlib.cat,cntlout=work.formatexport)

  @param [in] libcat The library.catalog reference
  @param [in] fmtlist= (0) provide a space separated list of specific formats to
    extract
  @param [in] iftrue= (1=1) A condition under which the macro should be executed
  @param [out] cntlout= (work.fmtextract) Libds reference for the output dataset

  <h4> SAS Macros </h4>
  @li mddl_sas_cntlout.sas
  @li mf_getuniquename.sas
  @li mp_aligndecimal.sas

  <h4> Related Macros </h4>
  @li mf_getvarformat.sas
  @li mp_getformats.sas
  @li mp_loadformat.sas
  @li mp_ds2fmtds.sas

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mp_cntlout(
  iftrue=(1=1)
  ,libcat=
  ,cntlout=work.fmtextract
  ,fmtlist=0
)/*/STORE SOURCE*/;
%local ddlds cntlds i;

%if not(%eval(%unquote(&iftrue))) %then %return;

%let ddlds=%mf_getuniquename();
%let cntlds=%mf_getuniquename();

%mddl_sas_cntlout(libds=&ddlds)

%if %index(&libcat,-)>0 and %scan(&libcat,2,-)=FC %then %do;
  %let libcat=%scan(&libcat,1,-);
%end;

proc format lib=&libcat cntlout=&cntlds;
%if "&fmtlist" ne "0" %then %do;
  select
  %do i=1 %to %sysfunc(countw(&fmtlist));
    %scan(&fmtlist,&i,%str( ))
  %end;
  ;
%end;
run;

data &cntlout;
  if 0 then set &ddlds;
  set &cntlds;
  if type in ("I","N") then do; /* numeric (in)format */
    %mp_aligndecimal(start,width=16)
    %mp_aligndecimal(end,width=16)
  end;
run;
proc sort;
  by type fmtname start;
run;

proc sql;
drop table &ddlds,&cntlds;

%mend mp_cntlout;
/** @endcond */