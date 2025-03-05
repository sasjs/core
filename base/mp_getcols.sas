/**
  @file
  @brief Creates a dataset with column metadata.
  @details This macro takes the `proc contents` output and "tidies it up" in the
  following ways:

    @li Blank labels are filled in with column names
    @li Formats are reconstructed with default values
    @li Types such as DATE / TIME / DATETIME are inferred from the formats

  Example usage:

      %mp_getcols(sashelp.airline,outds=work.myds)

  @param [in] ds The dataset from which to obtain column metadata
  @param [out] outds= (work.cols) The output dataset to create. Sample data:
|NAME:$32.|LENGTH:best.|VARNUM:best.|LABEL:$256.|FMTNAME:$32.|FORMAT:$49.|TYPE:$1.|DDTYPE:$9.|
|---|---|---|---|---|---|---|---|
|`AIR `|`8 `|`2 `|`international airline travel (thousands) `|` `|`8. `|`N `|`NUMERIC `|
|`DATE `|`8 `|`1 `|`DATE `|`MONYY `|`MONYY. `|`N `|`DATE `|
|`REGION `|`3 `|`3 `|`REGION `|` `|`$3. `|`C `|`CHARACTER `|


  <h4> Related Macros </h4>
  @li mf_getvarlist.sas
  @li mm_getcols.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_getcols(ds, outds=work.cols);
%local dropds;
proc contents noprint data=&ds
  out=_data_ (keep=name type length label varnum format:);
run;
%let dropds=&syslast;
data &outds(keep=name type length varnum format label ddtype fmtname);
  set &dropds(rename=(format=fmtname type=type2));
  name=upcase(name);
  if type2=2 then do;
    length format $49.;
    if fmtname='' then format=cats('$',length,'.');
    else if formatl=0 then format=cats(fmtname,'.');
    else format=cats(fmtname,formatl,'.');
    type='C';
    ddtype='CHARACTER';
  end;
  else do;
    if fmtname='' then format=cats(length,'.');
    else if formatl=0 then format=cats(fmtname,'.');
    else if formatd=0 then format=cats(fmtname,formatl,'.');
    else format=cats(fmtname,formatl,'.',formatd);
    type='N';
    if format=:'DATETIME' or format=:'E8601DT' or format=:'NLDATM'
    then ddtype='DATETIME';
    else if format=:'DATE' or format=:'DDMMYY' or format=:'MMDDYY'
      or format=:'YYMMDD' or format=:'E8601DA' or format=:'B8601DA'
      or format=:'MONYY' or format=:'NLDATE'
    then ddtype='DATE';
    else if format=:'TIME' then ddtype='TIME';
    else ddtype='NUMERIC';
  end;
  if label='' then label=name;
run;
proc sql;
drop table &dropds;
%mend mp_getcols;