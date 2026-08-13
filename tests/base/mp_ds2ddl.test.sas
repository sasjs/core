/**
  @file
  @brief Testing mp_ds2ddl.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2ddl.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data test(index=(pk=(x y)/unique /nomiss));
  x=1;
  y='blah';
  label x='blah';
run;
proc sql; describe table &syslast;
%mp_assertscope(SNAPSHOT)
%mp_ds2ddl(work,test,flavour=tsql,showlog=YES)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=mp_ds2ddl runs without errors,
  outds=work.test_results
)

%mp_assertscope(SNAPSHOT)
%mp_ds2ddl(work,test,flavour=sas,showlog=YES)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=mp_ds2ddl flavour=SAS (default) runs without errors,
  outds=work.test_results
)
