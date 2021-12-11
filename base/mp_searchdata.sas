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
      %mp_searchdata(lib=sashelp, ds=bird, numval=1)
      %mp_searchdata(lib=sashelp, ds=class, string=l,outobs=5)


  Outputs zero or more tables to an MPSEARCH library with specific records.

  @param [in] lib=  The libref to search (should be already assigned)
  @param [in] ds= The dataset to search (leave blank to search entire library)
  @param [in] string= String value to search (case sensitive, can be partial)
  @param [in] numval= Numeric value to search (must be exact)
  @param [out] outloc= (0) Optionally specify the directory in which to
    create the the output datasets with matching rows.  By default it will
    write them to a temporary subdirectory within the WORK folder.
  @param [out] outlib= (MPSEARCH) Assign a different libref to the output
    library containing the matching datasets / records
  @param [in] outobs= set to a positive integer to restrict the number of
    observations
  @param [in] filter_text= (1=1) Add a (valid) filter clause to further filter
    the results.

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_mkdir.sas
  @li mf_nobs.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mp_searchdata(lib=
  ,ds=
  ,string= /* the query will use a contains (?) operator */
  ,numval= /* numeric must match exactly */
  ,outloc=0
  ,outlib=MPSEARCH
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

%if "&outloc"="0" %then %do;
  %let outloc=%sysfunc(pathname(work))/%mf_getuniquename();
%end;

%mf_mkdir(&outloc)
libname &outlib "&outloc";

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
    /* prep input */
    data &outlib..&table;
      set &lib..&table;
      where %unquote(&filter_text) and ( 0
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
    %if &outobs>-1 %then %do;
      if _n_ > &outobs then stop;
    %end;
    run;
    %put Search query for &table took
      %sysevalf(%sysfunc(datetime())-&check_tm) seconds;
    %if &syscc ne 0 %then %do;
      %put %str(ERR)ROR: SYSCC=&syscc when processing &lib..&table;
      %return;
    %end;
    %if %mf_nobs(&outlib..&table)=0 %then %do;
      proc sql;
      drop table &outlib..&table;
    %end;
  %end;
%end;

%put process finished at %sysfunc(datetime(),datetime19.);

%mend mp_searchdata;
