/**
  @file
  @brief Searches all data in a library
  @details
  Scans an entire library and creates a copy of any table
    containing a specific string OR numeric value.  Only
    matching records are written out.
    If both a string and numval are provided, the string
    will take precedence.

  Usage:

      %mp_searchdata(lib=sashelp, string=Jan)
      %mp_searchdata(lib=sashelp, numval=1)


  Outputs zero or more tables to an MPSEARCH library with specific records.

  @param lib=  the libref to search (should be already assigned)
  @param ds= the dataset to search (leave blank to search entire library)
  @param string= the string value to search
  @param numval= the numeric value to search (must be exact)
  @param outloc= the directory in which to create the output datasets with
    matching rows.  Will default to a subfolder in the WORK library.
  @param outobs= set to a positive integer to restrict the number of
    observations
  @param filter_text= add a (valid) filter clause to further filter the results

  <h4> SAS Macros </h4>
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_mkdir.sas
  @li mf_nobs.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mp_searchdata(lib=sashelp
  ,ds=
  ,string= /* the query will use a contains (?) operator */
  ,numval= /* numeric must match exactly */
  ,outloc=%sysfunc(pathname(work))/mpsearch
  ,outobs=-1
  ,filter_text=%str(1=1)
)/*/STORE SOURCE*/;

%local table_list table table_num table colnum col start_tm check_tm vars type
  coltype;
%put process began at %sysfunc(datetime(),datetime19.);

%if &syscc ge 4 %then %do;
  %put %str(WAR)NING: SYSCC=&syscc on macro entry;
  %return;
%end;

%if &string = %then %let type=N;
%else %let type=C;

%mf_mkdir(&outloc)
libname mpsearch "&outloc";

/* get the list of tables in the library */
proc sql noprint;
select distinct memname into: table_list separated by ' '
  from dictionary.tables
  where upcase(libname)="%upcase(&lib)"
%if &ds ne %then %do;
  and upcase(memname)=%upcase("&ds")
%end;
  ;
/* check that we have something to check */
proc sql
%if &outobs>-1 %then %do;
  outobs=&outobs
%end;
;
%if %length(&table_list)=0 %then %put library &lib contains no tables!;
/* loop through each table */
%else %do table_num=1 %to %sysfunc(countw(&table_list,%str( )));
  %let table=%scan(&table_list,&table_num,%str( ));
  %let vars=%mf_getvarlist(&lib..&table);
  %if %length(&vars)=0 %then %do;
    %put NO COLUMNS IN &lib..&table!  This will be skipped.;
  %end;
  %else %do;
    %let check_tm=%sysfunc(datetime());
    /* build sql statement */
    create table mpsearch.&table as select * from &lib..&table
      where %unquote(&filter_text) and
    (0
    /* loop through columns */
    %do colnum=1 %to %sysfunc(countw(&vars,%str( )));
      %let col=%scan(&vars,&colnum,%str( ));
      %let coltype=%mf_getvartype(&lib..&table,&col);
      %if &type=C and &coltype=C %then %do;
        /* if a char column, see if it contains the string */
        or ("&col"n ? "&string")
      %end;
      %else %if &type=N and &coltype=N %then %do;
        /* if numeric match exactly */
        or ("&col"n = &numval)
      %end;
    %end;
    );
    %put Search query for &table took
      %sysevalf(%sysfunc(datetime())-&check_tm) seconds;
    %if &sqlrc ne 0 %then %do;
      %put %str(WAR)NING: SQLRC=&sqlrc when processing &table;
      %return;
    %end;
    %if %mf_nobs(mpsearch.&table)=0 %then %do;
      drop table mpsearch.&table;
    %end;
  %end;
%end;

%put process finished at %sysfunc(datetime(),datetime19.);

%mend mp_searchdata;
