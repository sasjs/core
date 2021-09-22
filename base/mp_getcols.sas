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

  @param ds The dataset from which to obtain column metadata
  @param outds= (work.cols) The output dataset to create. Sample data:
  |NAME $|LENGTH 8|VARNUM 8|LABEL $|FORMAT $49|TYPE $1 |DDTYPE $|
  |---|---|---|---|---|---|---|
  |AIR|8|2|international airline travel (thousands)|8.|N|NUMERIC|
  |DATE|8|1|DATE|MONYY.|N|DATE|
  |REGION|3|3|REGION|$3.|C|CHARACTER|

  <h4> Related Macros </h4>
  @li mf_getvarlist.sas
  @li mm_getcols.sas

  @version 9.2
  @author Allan Bowe
  @copyright Macro People Ltd - this is a licensed product and
    NOT FOR RESALE OR DISTRIBUTION.

**/

%macro mp_getcols(ds, outds=work.cols);

proc contents noprint data=&ds
  out=_data_ (keep=name type length label varnum format:);
run;
data &outds(keep=name type length varnum format label ddtype);
  set &syslast(rename=(format=format2 type=type2));
  name=upcase(name);
  if type2=2 then do;
    length format $49.;
    if format2='' then format=cats('$',length,'.');
    else if formatl=0 then format=cats(format2,'.');
    else format=cats(format2,formatl,'.');
    type='C';
    ddtype='CHARACTER';
  end;
  else do;
    if format2='' then format=cats(length,'.');
    else if formatl=0 then format=cats(format2,'.');
    else if formatd=0 then format=cats(format2,formatl,'.');
    else format=cats(format2,formatl,'.',formatd);
    type='N';
    if format=:'DATETIME' then ddtype='DATETIME';
    else if format=:'DATE' or format=:'DDMMYY' or format=:'MMDDYY'
      or format=:'YYMMDD' or format=:'E8601DA' or format=:'B8601DA'
      or format=:'MONYY'
    then ddtype='DATE';
    else if format=:'TIME' then ddtype='TIME';
    else ddtype='NUMERIC';
  end;
  if label='' then label=name;
run;

%mend mp_getcols;