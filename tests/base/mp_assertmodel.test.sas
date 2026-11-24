/**
  @file
  @brief Test dataset model and primary key assertions

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

**/

data work.model;
  length id 8 region $4 value $12;
  call missing(id,region,value);
  stop;
run;

data work.match;
  length value $12 region $4 id 8;
  id=1; region='A'; value='one'; output;
  id=1; region='B'; value='two'; output;
run;

data work.extra;
  set work.match;
  extra=1;
run;

data work.wronglen;
  length id 8 region $4 value $11;
  call missing(id,region,value);
  stop;
run;

data work.duplicate;
  set work.match;
  output;
  if id=1 then output;
run;

data work.missingkey;
  set work.match;
  if id=1 then region=' ';
run;

/* Keep expected FAIL rows separate from the test harness results. */
%mp_assertscope(SNAPSHOT)
%mp_assertmodel(work.match,base=work.model,key=id region,
  desc=match,outds=work.model_results)
%mp_assertscope(COMPARE,desc=Model assertion does not leak macro variables)
%mp_assertmodel(work.model,base=work.model,key=id,
  desc=empty,outds=work.model_results)
%mp_assertmodel(work.extra,base=work.model,
  desc=extra,outds=work.model_results)
%mp_assertmodel(work.wronglen,base=work.model,
  desc=length,outds=work.model_results)
%mp_assertmodel(work.duplicate,base=work.model,key=id region,
  desc=duplicate,outds=work.model_results)
%mp_assertmodel(work.missingkey,base=work.model,key=id region,
  desc=missing_key,outds=work.model_results)
%mp_assertmodel(work.match,base=work.model,key=absent,
  desc=unknown_key,outds=work.model_results)
%mp_assertmodel(work.notfound,base=work.model,
  desc=missing_input,outds=work.model_results)

data work.expected;
  length test_description $256 test_result $5 reason $80;
  infile datalines dlm='|' truncover;
  input test_description $ test_result $ reason $;
  datalines;
match|PASS|Column model and key match
empty|PASS|Column model and key match
extra|FAIL|Column count differs
length|FAIL|Type or length differs
duplicate|FAIL|Key contains missing or duplicate
missing_key|FAIL|Key contains missing or duplicate
unknown_key|FAIL|Key column not found
missing_input|FAIL|Input dataset cannot be opened
;
run;

proc sql noprint;
  select count(*),count(distinct e.test_description)
    into :model_rows trimmed,:model_matches trimmed
  from work.model_results as a left join work.expected as e
    on a.test_description=e.test_description
    and a.test_result=e.test_result
    and index(a.test_comments,strip(e.reason))>0;
quit;
%mp_assert(iftrue=(&model_rows=8 and &model_matches=8),
  desc=Model results match expected pass and fail cases)

/* An overlapping destination is rejected without changing the input. */
%let model_syntax=%sysfunc(getoption(syntaxcheck,keyword));
options nosyntaxcheck;
%mp_assertmodel(work.match,base=work.model,outds=work.match)
%let model_errorcc=&syscc;
%let syscc=0;
options &model_syntax;
proc sql noprint;
  select count(*) into :model_input_rows trimmed from work.match;
quit;
%mp_assert(iftrue=(&model_errorcc>4 and &model_input_rows=2),
  desc=Overlapping output is rejected and input preserved)
