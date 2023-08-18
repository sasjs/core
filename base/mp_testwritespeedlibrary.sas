/**
  @file mp_testwritespeedlibrary.sas
  @brief Tests the write speed of a new table in a SAS library
  @details Will create a new table of a certain size in an
  existing SAS library.  The table will have one column,
  and will be subsequently deleted.

      %mp_testwritespeedlibrary(
        lib=work
        ,size=0.5
        ,outds=work.results
      )

  @param [in] lib= (WORK) The library in which to create the table
  @param [in] size= (0.1) The size in GB of the table to create
  @param [out] outds= (WORK.RESULTS) The output dataset to be created.

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mf_existds.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mp_testwritespeedlibrary(lib=WORK
  ,outds=work.results
  ,size=0.1
)/*/STORE SOURCE*/;
%local ds start;

/* find an unused, unique name for the new table */
%let ds=%mf_getuniquename();
%do %until(%mf_existds(&lib..&ds)=0);
  %let ds=%mf_getuniquename();
%end;

%let start=%sysfunc(datetime());

data &lib..&ds(compress=no keep=x);
  header=128*1024;
  size=(1073741824/8 * &size) - header;
  do x=1 to size;
    output;
  end;
run;

proc sql;
drop table &lib..&ds;

data &outds;
  lib="&lib";
  start_dttm=put(&start,datetime19.);
  end_dttm=put(datetime(),datetime19.);
  duration_seconds=end_dttm-start_dttm;
run;

%mend mp_testwritespeedlibrary;