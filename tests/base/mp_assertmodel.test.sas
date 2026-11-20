/**
  @file
  @brief Test exact dataset model and optional primary key assertions

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
  id=2; region='B'; value='two'; output;
run;

data work.extra;
  set work.match;
  extra=1;
run;

data work.missingcol;
  set work.match(drop=value);
run;

data work.wrongname;
  set work.match(rename=(value=other));
run;

data work.wronglen;
  length value $11 region $4 id 8;
  call missing(value,region,id);
  stop;
run;

data work.wrongtype;
  length value $12 region $4 id $8;
  call missing(value,region,id);
  stop;
run;

data work.empty;
  set work.model;
run;

data work.duplicate;
  set work.match;
  output;
  if id=1 then output;
run;

data work.missingkey;
  set work.match;
  if id=1 then id=.A;
run;

data work.blankkey;
  set work.match;
  if id=1 then region=' ';
run;

data work.composite;
  set work.match;
  id=1;
run;

data work.sqlkeys;
  length case 8 user $12;
  case=1; user='a'; output;
  case=2; user='b'; output;
run;

data work.sqlkeys_duplicate;
  set work.sqlkeys;
  user='a';
run;

data work.sqlkeys_missing;
  set work.sqlkeys;
  if case=1 then user=' ';
run;

data work.assertmodel_results;
  length test_description $256 test_result $5 test_comments $256;
  call missing(test_description,test_result,test_comments);
  stop;
run;

%macro check_model(case=,inds=,base=work.model,key=,expect=);
  %local matched total;
  %mp_assertmodel(&inds,base=&base,key=&key,desc=&case,
    outds=work.assertmodel_results)
  proc sql noprint;
    select count(*),sum(test_result="&expect")
      into :total trimmed,:matched trimmed
    from work.assertmodel_results where test_description="&case";
  quit;
  %mp_assert(iftrue=(&total=1 and &matched=1),
    desc=Model assertion case &case)
%mend check_model;

%mp_assertscope(SNAPSHOT)
%check_model(case=match_order_independent,inds=work.match,expect=PASS)
%mp_assertscope(COMPARE,desc=Model assertion does not leak macro variables)
%check_model(case=empty_dataset,inds=work.empty,key=id region,expect=PASS)
%check_model(case=valid_key,inds=work.match,key=id,expect=PASS)
%check_model(case=composite_key,inds=work.composite,key=id region,expect=PASS)
%check_model(case=extra_column,inds=work.extra,expect=FAIL)
%check_model(case=missing_column,inds=work.missingcol,expect=FAIL)
%check_model(case=renamed_column,inds=work.wrongname,expect=FAIL)
%check_model(case=wrong_length,inds=work.wronglen,expect=FAIL)
%check_model(case=wrong_type,inds=work.wrongtype,expect=FAIL)
%check_model(case=duplicate_key,inds=work.duplicate,key=id region,expect=FAIL)
%check_model(case=missing_numeric_key,inds=work.missingkey,key=id,expect=FAIL)
%check_model(case=missing_character_key,inds=work.blankkey,
  key=id region,expect=FAIL)
%check_model(case=missing_key_column,inds=work.match,key=absent,expect=FAIL)
%check_model(case=missing_input,inds=work.notfound,expect=FAIL)
%check_model(case=missing_base,inds=work.match,base=work.notfound,expect=FAIL)
%check_model(case=reserved_key,inds=work.sqlkeys,base=work.sqlkeys,
  key=case user,expect=PASS)
%check_model(case=reserved_duplicate,inds=work.sqlkeys_duplicate,
  base=work.sqlkeys,key=user,expect=FAIL)
%check_model(case=reserved_missing,inds=work.sqlkeys_missing,
  base=work.sqlkeys,key=user,expect=FAIL)
