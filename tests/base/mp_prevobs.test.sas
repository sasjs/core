/**
  @file
  @brief Testing mp_prevobs macro

  <h4> SAS Macros </h4>
  @li mp_prevobs.sas
  @li mp_assert.sas

  @details mp_prevobs emits statements into a data step, so it is exercised
  inside one and the result is checked after the step.  FETCH -1 reinstates the
  observation one row before the current one.

**/

data work.prevobs_src;
  do id=1 to 5;
    lbl=byte(96+id);
    output;
  end;
run;

data work.prevobs_out;
  set work.prevobs_src;
  %mp_prevobs(INIT,history=2)
  if _n_=4 then do;
    %mp_prevobs(FETCH,-1)
    restored=lbl;
    restored_id=id;
    output;
  end;
run;

proc sql noprint;
  select count(*) into: n_rows from work.prevobs_out;
  select restored into: restored from work.prevobs_out(obs=1);
  select restored_id into: restored_id from work.prevobs_out(obs=1);
quit;

%mp_assert(
  iftrue=(&n_rows=1),
  desc=Checking that the fetch of the previous observation succeeded,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(strip(&restored))=c and &restored_id=3),
  desc=Checking that the observation one row back is reinstated,
  outds=work.test_results
)
