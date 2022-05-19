/**
  @file
  @brief Testing mp_jsonout.sas macro with special missings

  <h4> SAS Macros </h4>
  @li mp_jsonout.sas
  @li mp_assert.sas

**/

filename webref temp;

data demo;
  do x=._,.,.a,.b,.c,.d,.e,-99, 0, 1,2, 3.333333;
    output;
  end;
run;
%mp_jsonout(OPEN,jref=webref)
%mp_jsonout(OBJ,demo,jref=webref,fmt=N,missing=STRING)
%mp_jsonout(CLOSE,jref=webref)

data _null_;
  infile webref;
  input;
  putlog _infile_;
run;

libname web JSON fileref=webref;

/* proc json turns to char - so switch back to numeric */
data work.test(keep=x);
  set web.demo(rename=(x=y));
  if y ='_' then x=._;
  else if anyalpha(y) then x=input(cats(".",y),best.);
  else x=input(y,best.);
  put (_all_)(=);
run;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking for error condition with special missing export,
  outds=work.test_results
)

proc compare base=work.demo compare=work.test;
quit;

%mp_assert(
  iftrue=(&sysinfo=0),
  desc=Returned json is identical to input table for all special missings,
  outds=work.test_results
)