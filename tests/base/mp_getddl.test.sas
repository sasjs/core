/**
  @file
  @brief Testing mp_getddl.sas macro

  <h4> SAS Macros </h4>
  @li mp_getddl.sas
  @li mp_assert.sas

**/

data test(index=(pk=(x y)/unique /nomiss));
  x=1;
  y='blah';
  label x='blah';
run;
proc sql; describe table &syslast;
%mp_getddl(work,test,flavour=tsql,showlog=YES)

%mp_assert(
  iftrue=(&syscc=0),
  desc=mp_getddl runs without errors,
  outds=work.test_results
)