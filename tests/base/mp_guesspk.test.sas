/**
  @file
  @brief Testing mp_guesspk macro

  <h4> SAS Macros </h4>
  @li mp_guesspk.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

**/

%let guess_saved_obs=%sysfunc(getoption(obs,keyword));
%let guess_saved_firstobs=%sysfunc(getoption(firstobs,keyword));
options obs=max firstobs=1;

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

data work.pk_model;
  length pkguesses $5000;
  call missing(pkguesses);
  stop;
run;

%mp_assertmodel(work.pk_out,base=work.pk_model,key=pkguesses,
  desc=Checking mp_guesspk output model and key,
  outds=work.test_results
)

proc sql noprint;
  select count(*) into: n_rows from work.pk_out;
  select count(*) into: n_id from work.pk_out where pkguesses='ID';
  select count(*) into: n_idgrp from work.pk_out where pkguesses='ID GRP';
quit;

%mp_assert(
  iftrue=(&n_rows>0),
  desc=Checking that at least one candidate primary key is proposed,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_rows=2 and &n_id=1 and &n_idgrp=1),
  desc=Checking exact mp_guesspk row count and values,
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

options &guess_saved_obs &guess_saved_firstobs;
