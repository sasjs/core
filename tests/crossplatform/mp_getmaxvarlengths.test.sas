/**
  @file
  @brief Testing mp_getmaxvarlengths macro

  <h4> SAS Macros </h4>
  @li mp_getmaxvarlengths.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/

data work.class ;
attrib
Name                             length= $8
Sex                              length= $1
Age                              length= 8
Height                           length= 8
Weight                           length= 8
;
infile cards dsd;
input
  Name                             :$char.
  Sex                              :$char.
  Age
  Height
  Weight
;
datalines4;
Alfred,M,14,69,112.5
Alice,F,13,56.5,84
Barbara,F,13,65.3,98
Carol,F,14,62.8,102.5
Henry,M,14,63.5,102.5
James,M,12,57.3,83
Jane,F,12,59.8,84.5
Janet,F,15,62.5,112.5
Jeffrey,M,13,62.5,84
John,M,12,59,99.5
Joyce,F,11,51.3,50.5
Judy,F,14,64.3,90
Louise,F,12,56.3,77
Mary,F,15,66.5,112
Philip,M,16,72,150
Robert,M,12,64.8,128
Ronald,M,15,67,133
Thomas,M,11,57.5,85
William,M,15,66.5,112
;;;;
run;

/* regular usage */
%mp_assertscope(SNAPSHOT)
%mp_getmaxvarlengths(work.class,outds=work.myds)
%mp_assertscope(COMPARE,desc=checking scope leakage on mp_getmaxvarlengths)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errs
)
%mp_assertdsobs(work.myds,
  desc=Has 5 records,
  test=EQUALS 5
)
data work.errs;
  set work.myds;
  if name='Name' and maxlen ne 7 then output;
  if name='Sex' and maxlen ne 1 then output;
  if name='Age' and maxlen ne 3 then output;
  if name='Height' and maxlen ne 8 then output;
  if name='Weight' and maxlen ne 3 then output;
run;
data _null_;
  set work.errs;
  putlog (_all_)(=);
run;

%mp_assertdsobs(work.errs,
  desc=Err table has 0 records,
  test=EQUALS 0
)

/* test2 */
data work.test2;
  length a 3 b 5;
  a=1/3;
  b=1/3;
  c=1/3;
  d=._;
  e=.;
  output;
  output;
run;
%mp_getmaxvarlengths(work.test2,outds=work.myds2)
%mp_assert(
  iftrue=(&syscc=0),
  desc=No errs in second test (with nulls)
)
%mp_assertdsobs(work.myds2,
  desc=Has 5 records,
  test=EQUALS 5
)
data work.errs2;
  set work.myds2;
  if name='a' and maxlen ne 3 then output;
  if name='b' and maxlen ne 5 then output;
  if name='c' and maxlen ne 8 then output;
  if name='d' and maxlen ne 3 then output;
  if name='e' and maxlen ne 0 then output;
run;
data _null_;
  set work.errs2;
  putlog (_all_)(=);
run;

%mp_assertdsobs(work.errs2,
  desc=Err table has 0 records,
  test=EQUALS 0
)