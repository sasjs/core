/**
  @file
  @brief Testing mf_getvarlist macro

  <h4> SAS Macros </h4>
  @li mf_getvarlist.sas

**/


%let test1=%mf_getvarlist(sashelp.class);
%let test2=%mf_getvarlist(sashelp.class,dlm=X);
%let test3=%mf_getvarlist(sashelp.class,dlm=%str(,),quote=double);
%let test4=%mf_getvarlist(sashelp.class,typefilter=N);
%let test5=%mf_getvarlist(sashelp.class,typefilter=C);

data work.test_results;
  length test_description $256 test_result $4 test_comments base result  $256;
  test_description="Basic test";
  base=symget('test1');
  result='Name Sex Age Height Weight';
  if base=result then test_result='PASS';
  else test_result='FAIL';
  test_comments="Comparing "!!trim(base)!!' vs '!!trim(result);
  output;

  test_description="DLM test";
  base=symget('test2');
  result='NameXSexXAgeXHeightXWeight';
  if base=result then test_result='PASS';
  else test_result='FAIL';
  test_comments="Comparing "!!trim(base)!!' vs '!!trim(result);
  output;

  test_description="DLM + quote test";
  base=symget('test3');
  result='"Name","Sex","Age","Height","Weight"';
  if base=result then test_result='PASS';
  else test_result='FAIL';
  test_comments="Comparing "!!trim(base)!!' vs '!!trim(result);
  output;

  test_description="Numeric Filter";
  base=symget('test4');
  result='Age Height Weight';
  if base=result then test_result='PASS';
  else test_result='FAIL';
  test_comments="Comparing "!!trim(base)!!' vs '!!trim(result);
  output;

  test_description="Char Filter";
  base=symget('test5');
  result='Name Sex';
  if base=result then test_result='PASS';
  else test_result='FAIL';
  test_comments="Comparing "!!trim(base)!!' vs '!!trim(result);
  output;

  drop base result;
run;