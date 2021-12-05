/**
  @file
  @brief Sorts a SAS dataset in place, preserving constraints
  @details Generally if a dataset contains indexes, then it is not necessary to
  sort it before performing operations such as merges / joins etc.
  That said, there are a few edge cases where it can be desirable:

    @li To improve performance for particular scenarios
    @li To allow adjacent records to be viewed directly in the dataset
    @li To reduce dataset size (eg when there are deleted records)

  This macro will only work for BASE (V9) engine libraries.  It works by
  creating a copy of the dataset (without data, WITH constraints) in the same
  library, appending a sorted view into it, and finally - renaming it.

  Example usage:

      proc sql;
      create table work.example as
        select * from sashelp.class;
      alter table work.example
        add constraint pk primary key(name);
      %mp_sortinplace(work.example)

  @param [in] libds The libref.datasetname that needs to be sorted

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_getengine.sas
  @li mf_getquotedstr.sas
  @li mf_getuniquename.sas
  @li mf_nobs.sas
  @li mp_abort.sas
  @li mp_getpk.sas

  <h4> Related Macros </h4>
  @li mp_sortinplace.test.sas

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_sortinplace(libds
)/*/STORE SOURCE*/;

%local lib ds tempds1 tempds2 tempvw sortkey;

/* perform validations */
%mp_abort(iftrue=(%sysfunc(countc(&libds,.)) ne 1)
  ,mac=mp_sortinplace
  ,msg=%str(LIBDS (&libds) should have LIBREF.DATASET format)
)
%mp_abort(iftrue=(%mf_existds(&libds)=0)
  ,mac=mp_sortinplace
  ,msg=%str(&libds does not exist)
)

%let lib=%scan(&libds,1,.);
%let ds=%scan(&libds,2,.);
%mp_abort(iftrue=(%mf_getengine(&lib) ne V9)
  ,mac=mp_sortinplace
  ,msg=%str(&lib is not a BASE engine library)
)

/* grab a copy of the constraints so we know what to sort by */
%let tempds1=%mf_getuniquename(prefix=&sysmacroname);
%mp_getpk(lib=&lib,ds=&ds,outds=work.&tempds1)

%if %mf_nobs(work.&tempds1)=0 %then %do;
  %put &sysmacroname: No PK found in &lib..&ds;
  %put Sorting will not take place;
  %return;
%end;

data _null_;
  set work.&tempds1;
  call symputx('sortkey',pk_fields);
run;


/* create empty copy, with ALL constraints, in the same library */
%let tempds2=%mf_getuniquename(prefix=&sysmacroname);
proc append base=&lib..&tempds2 data=&libds(obs=0);
run;

/* create sorted view */
%let tempvw=%mf_getuniquename(prefix=&sysmacroname);
proc sql;
create view work.&tempvw as select * from &lib..&ds
order by %mf_getquotedstr(&sortkey,quote=%str());

/* append sorted data */
proc append base=&lib..&tempds2 data=work.&tempvw;
run;

/* do validations */
%mp_abort(iftrue=(&syscc ne 0)
  ,mac=mp_sortinplace
  ,msg=%str(syscc=&syscc prior to replace operation)
)
%mp_abort(iftrue=(%mf_nobs(&lib..&tempds2) ne %mf_nobs(&lib..&ds))
  ,mac=mp_sortinplace
  ,msg=%str(new dataset has a different number of logical obs to the old)
)

/* drop old dataset */
proc sql;
drop table &lib..&ds;

/* rename the new dataset */
proc datasets library=&lib;
  change &tempds2=&ds;
run;


%mend mp_sortinplace;