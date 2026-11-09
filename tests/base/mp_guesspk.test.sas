/**
  @file
  @brief Testing mp_guesspk macro

  <h4> SAS Macros </h4>
  @li mp_guesspk.sas
  @li mp_assert.sas

**/

data work.pkdata;
  do id=1 to 10;
    grp=ifn(id<6,1,2);
    output;
  end;
run;

%mp_guesspk(baseds=work.pkdata,outds=work.pk_out)

proc sql noprint;
  select count(*) into: n_rows from work.pk_out;
quit;

%mp_assert(
  iftrue=(&n_rows>0),
  desc=Checking that at least one candidate primary key is proposed,
  outds=work.test_results
)
