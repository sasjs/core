/**
  @file
  @brief Testing mp_guesspk macro

  <h4> SAS Macros </h4>
  @li mp_guesspk.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.pkdata;
  do id=1 to 10;
    grp=ifn(id<6,1,2);
    output;
  end;
run;

%mp_assertscope(SNAPSHOT)
%mp_guesspk(baseds=work.pkdata,outds=work.pk_out)
%mp_assertscope(COMPARE,
  desc=Checking mp_guesspk normal call does not leak scope,
  outds=work.test_results
)

proc sql noprint;
  select count(*) into: n_rows from work.pk_out;
quit;

%mp_assert(
  iftrue=(&n_rows>0),
  desc=Checking that at least one candidate primary key is proposed,
  outds=work.test_results
)

data work.pk_duplicates;
  set work.pkdata;
  output;
  if id=1 then output;
run;

%mp_assertscope(SNAPSHOT)
%mp_guesspk(baseds=work.pk_duplicates,outds=work.pk_no_unique)
%mp_assertscope(COMPARE,
  desc=Checking mp_guesspk no unique combination return does not leak scope,
  outds=work.test_results
)
