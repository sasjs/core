/**
  @file
  @brief Apply a set of formats to a table
  @details Applies a set of formats to one or more SAS datasets.  Can be used
    to migrate formats from one table to another.  The input table must contain
    the following columns:

    @li lib - the libref of the table to be updated
    @li ds - the dataset to be updated
    @li var - the variable to be updated
    @li fmt - the format to apply.  Missing or default ($CHAR, 8.) formats are
      ignored.

  The macro will abort in the following scenarios:

    @li Libref not assigned
    @li Dataset does not exist
    @li Input table contains null or invalid values

  Example usage:

      data work.example;
        set sashelp.prdsale;
        format _all_ clear;
      run;

      %mp_getcols(sashelp.prdsale,outds=work.cols)

      data work.cols2;
        set work.cols;
        lib='WORK';
        ds='EXAMPLE';
        var=name;
        fmt=format;
        keep lib ds var fmt;
      run;

      %mp_applyformats(work.cols2)

  @param [in] inds The input dataset containing the formats to apply (and where
    to apply them).  Example structure:
  |LIB:$8.|DS:$32.|VAR:$32.|FMT:$49.|
  |---|---|---|---|
  |`WORK `|`EXAMPLE `|`ACTUAL `|`DOLLAR12.2 `|
  |`WORK `|`EXAMPLE `|`COUNTRY `|`$CHAR10. `|
  |`WORK `|`EXAMPLE `|`DIVISION `|`$CHAR10. `|
  |`WORK `|`EXAMPLE `|`MONTH `|`MONNAME3. `|
  |`WORK `|`EXAMPLE `|`PREDICT `|`DOLLAR12.2 `|
  |`WORK `|`EXAMPLE `|`PRODTYPE `|`$CHAR10. `|
  |`WORK `|`EXAMPLE `|`PRODUCT `|`$CHAR10. `|
  |`WORK `|`EXAMPLE `|`QUARTER `|`8. `|
  |`WORK `|`EXAMPLE `|`REGION `|`$CHAR10. `|
  |`WORK `|`EXAMPLE `|`YEAR `|`8. `|

  @param [out] errds= (0) Provide a libds reference here to export the
    error messages to a table.  In this case, they will not be printed to the
    log.

  <h4> SAS Macros </h4>
  @li mf_getengine.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_nobs.sas
  @li mp_validatecol.sas


  <h4> Related Macros </h4>
  @li mp_getformats.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_applyformats(inds,errds=0
)/*/STORE SOURCE*/;
%local outds liblist i engine lib msg ;

/**
  * Validations
  */
proc sort data=&inds;
  by lib ds var fmt;
run;

%if &errds=0 %then %let outds=%mf_getuniquename(prefix=mp_applyformats);
%else %let outds=&errds;

data &outds;
  set &inds;
  where fmt not in ('','.', '$', '$CHAR.','8.');
  length msg $128;
  by lib ds var fmt;
  if libref(lib) ne 0 then do;
    msg=catx(' ','libref',lib,'is not assigned!');
    %if &errds=0 %then %do;
      putlog "%str(ERR)OR: " msg;
    %end;
    output;
    return;
  end;
  if exist(cats(lib,'.',ds)) ne 1 then do;
    msg=catx(' ','libds',lib,'.',ds,'does not exist!');
    %if &errds=0 %then %do;
      putlog "%str(ERR)OR: " msg;
    %end;
    output;
    return;
  end;
  %mp_validatecol(fmt,FORMAT,is_fmt)
  if is_fmt=0 then do;
    msg=catx(' ','format',fmt,'on libds',lib,'.',ds,'.',var,'is not valid!');
    %if &errds=0 %then %do;
      putlog "%str(ERR)OR: " msg;
    %end;
    output;
    return;
  end;

  if first.ds then do;
    retain dsid;
    dsid=open(cats(lib,'.',ds));
    if dsid=0 then do;
      msg=catx(' ','libds',lib,'.',ds,' could not be opened!');
      %if &errds=0 %then %do;
        putlog "%str(ERR)OR: " msg;
      %end;
      output;
      return;
    end;
    if varnum(dsid,var)<1 then do;
      msg=catx(' ','Variable',lib,'.',ds,'.',var,' was not found!');
      %if &errds=0 %then %do;
        putlog "%str(ERR)OR: " msg;
      %end;
      output;
    end;
  end;
  if last.ds then rc=close(dsid);
run;

proc sql noprint;
select distinct lib into: liblist separated by ' ' from &inds;
%put &=liblist;
%do i=1 %to %sysfunc(countw(&liblist));
  %let lib=%scan(&liblist,1);
  %let engine=%mf_getengine(&lib);
  %if &engine ne V9 and &engine ne BASE %then %do;
    %let msg=&lib has &engine engine - formats cannot be applied;
    proc sql;
    insert into &outds set lib="&lib",ds="_all_",var="_all", msg="&msg" ;
    %if &errds=0 %then %put %str(ERR)OR: &msg;
  %end;
%end;

%if %mf_nobs(&outds)>0 %then %return;

/**
  * Validations complete - now apply the actual formats!
  */
%let fref=%mf_getuniquefileref();
data _null_;
  set &inds;
  by lib ds var fmt;
  where fmt not in ('','.', '$', '$CHAR.','8.');
  file &fref;
  if first.lib then put 'proc datasets nolist lib=' lib ';';
  if first.ds then put '  modify ' ds ';';
  put '    format ' var fmt ';';
  if last.ds then put '  run;';
  if last.lib then put 'quit;';
run;

%inc &fref/source2;

%if &errds=0 %then %do;
  proc sql;
  drop table &outds;
%end;

%mend mp_applyformats;