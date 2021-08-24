/**
  @file
  @brief Convert all data in a library to SQL insert statements
  @details Gets list of members then calls the <code>%mp_ds2inserts()</code>
  macro.
  Usage:

      %mp_getddl(sashelp, schema=work, fref=tempref)

      %mp_lib2inserts(sashelp, schema=work, outref=tempref)

      %inc tempref;


  The output will be one file in the outref fileref.


  <h4> SAS Macros </h4>
  @li mp_ds2inserts.sas


  @param [in] lib Library in which to convert all datasets to inserts
  @param [in] flavour= (SAS) The SQL flavour to be applied to the output. Valid
    options:
    @li SAS (default) - suitable for regular proc sql
    @li PGSQL - Used for Postgres databases
  @param [in] maxobs= (max) The max number of observations (per table) to create
  @param [out] outref= Output fileref in which to create the insert statements.
    If it exists, it will be appended to, otherwise it will be created.
  @param [out] schema= (0) The schema of the target database, or the libref.
  @param [in] applydttm= (YES) If YES, any columns using datetime formats will
    be converted to native DB datetime literals

  @version 9.2
  @author Allan Bowe
**/

%macro mp_lib2inserts(lib
    ,flavour=SAS
    ,outref=0
    ,schema=0
    ,maxobs=max
    ,applydttm=YES
)/*/STORE SOURCE*/;

/* Find the tables */
%local x ds memlist;
proc sql noprint;
select distinct lowcase(memname)
  into: memlist
  separated by ' '
  from dictionary.tables
  where upcase(libname)="%upcase(&lib)"
    and memtype='DATA'; /* exclude views */


%let flavour=%upcase(&flavour);
%if &flavour ne SAS and &flavour ne PGSQL %then %do;
  %put %str(WAR)NING:  &flavour is not supported;
  %return;
%end;


/* create the inserts */
%do x=1 %to %sysfunc(countw(&memlist));
  %let ds=%scan(&memlist,&x);
  %mp_ds2inserts(&lib..&ds
    ,outref=&outref
    ,schema=&schema
    ,outds=&ds
    ,flavour=&flavour
    ,maxobs=&maxobs
    ,applydttm=&applydttm
  )
%end;

%mend mp_lib2inserts;