/**
  @file
  @brief Testing mp_ds2inserts.sas macro

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mp_getddl.sas
  @li mp_lib2inserts.sas
  @li mp_assert.sas

**/

/* grab 20 datasets from SASHELP */
%let work=%sysfunc(pathname(work));
%let path=&work/new;
%mf_mkdir(&path)
libname sashlp "&work";
proc sql noprint;
create table members as
  select distinct lowcase(memname) as memname
  from dictionary.tables
  where upcase(libname)="SASHELP"
    and memtype='DATA'; /* exclude views */
data _null_;
  set work.members;
  call execute(cats('data sashlp.',memname,';set sashelp.',memname,';run;'));
  if _n_>20 then stop;
run;

/* export DDL and inserts */
%mp_getddl(sashlp, schema=work, fref=tempref)
%mp_lib2inserts(sashlp, schema=work, outref=tempref,maxobs=50)

/* check if it actually runs */
libname sashlp "&path";
options source2;
%inc tempref;

/* without errors.. */
%mp_assert(
  iftrue=(&syscc=0),
  desc=Able to export 20 tables from sashelp using mp_lib2inserts,
  outds=work.test_results
)