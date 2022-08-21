/**
  @file
  @brief Testing mp_dsmeta.sas macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_dsmeta.sas

**/

data work.Example;
  set sashelp.vmacro;
run;

%mp_assertscope(SNAPSHOT)
%mp_dsmeta(work.example,outds=work.test)
%mp_assertscope(COMPARE)

proc sql noprint;
select count(*) into: nobs from work.test;
select count(distinct ods_table) into: tnobs from work.test;

%mp_assert(
  iftrue=(&tnobs=2),
  desc=Check that both ATTRIBUTES and ENGINEHOST are provided
)
%mp_assert(
  iftrue=(&nobs>10),
  desc=Check that sufficient details are provided
)

