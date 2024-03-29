/**
  @file
  @brief Testing mp_sortinplace.test.sas

  <h4> SAS Macros </h4>
  @li mp_sortinplace.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_getconstraints.sas

**/


/** Test 1 - regular usage  */
proc sql;
create table work.example as
  select * from sashelp.classfit;
alter table work.example
  add constraint pk primary key(name);
%mp_sortinplace(work.example)

%mp_getconstraints(lib=work,ds=example,outds=work.testme)

%mp_assertdsobs(work.testme,
  desc=Test1 - check constraints recreated,
  test=EQUALS 1,
  outds=work.test_results
)

%let test1=0;
data _null_;
  set work.example;
  call symputx('test1',name);
  stop;
run;
%mp_assert(
  iftrue=(
    %str(&test1)=%str(Alfred)
  ),
  desc=Check if sort was appplied,
  outds=work.test_results
)

/** Test 2 - table without PK  */
proc sql;
create table work.example2 as
  select * from sashelp.classfit;
%mp_sortinplace(work.example2)
%mp_assert(
  iftrue=(
    %str(&syscc)=%str(0)
  ),
  desc=Ensure no errors when no key exists,
  outds=work.test_results
)

%let test2=0;
data _null_;
  set work.example2;
  call symputx('test2',name);
  stop;
run;
%mp_assert(
  iftrue=(
    %str(&test2)=%str(Alfred)
  ),
  desc=Check if sort was appplied when no index exists,
  outds=work.test_results
)