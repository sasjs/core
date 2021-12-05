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

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_getuniquename.sas
  @li mp_abort.sas

  <h4> Related Macros </h4>
  @li mf_getvalue.sas

  @param [in] libds The libref.datasetname that needs to be sorted

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_sortinplace(libds
)/*/STORE SOURCE*/;

%local lib ds tempds1 tempds2 tempvw;

/* perform validations */
%mp_abort(iftrue=(%sysfunc(countw(&libds,.)) ne 1)
  ,mac=&sysmacroname
  ,msg=%str(LIBDS (&libds) should have LIBREF.DATASET format)
)
%mp_abort(iftrue=(%mf_existds(&libds)=0)
  ,mac=&sysmacroname
  ,msg=%str(&libds does not exist)
)

%let lib=%scan(&libds,1,.);
%let ds=%scan(&libds,2,.);
%mp_abort(iftrue=(&lib ne V9)
  ,mac=&sysmacroname
  ,msg=%str(&lib is not a BASE engine library)
)

/* grab a copy of the constraints so we know what to sort by */
%let tempds1=%mf_getuniquename(prefix=&sysmacroname);
%mp_getconstraints(lib=&lib,ds=example,outds=work.&tempds1)

/* create empty copy, WITH constraints, in the same library */
%let tempds2=%mf_getuniquename(prefix=&sysmacroname);
proc append base=&lib..&tempds2 data=&libds(obs=0);
run;

%let tempvw=%mf_getuniquename(prefix=&sysmacroname);
proc sql;




%mend mp_sortinplace;