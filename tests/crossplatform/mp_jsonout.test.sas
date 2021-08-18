/**
  @file
  @brief Testing mp_jsonout.sas macro

  <h4> SAS Macros </h4>
  @li mp_jsonout.sas
  @li mp_assert.sas

**/

filename webref temp;

data demo;
  dtval=date();
  format dtval date9.;
  compare=put(date(),date9.);
  call symputx('compare',compare);
run;

%mp_jsonout(OPEN,jref=webref)
%mp_jsonout(OBJ,demo,jref=webref,fmt=Y)
%mp_jsonout(CLOSE,jref=webref)

data _null_;
  infile webref;
  input;
  putlog _infile_;
run;

libname web JSON fileref=webref;
%let dtval=0;
data work.test;
  set web.demo;
  call symputx('dtval',dtval);
run;


%mp_assert(
  iftrue=(&dtval=&compare),
  desc=Checking tables were created successfully,
  outds=work.test_results
)