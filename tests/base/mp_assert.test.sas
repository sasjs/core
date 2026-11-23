/**
  @file
  @brief Testing mp_assert macro
  @details This is quite "meta".. it's just testing itself

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertmodel.sas

**/

%mp_assert(
  iftrue=(1=1),
  desc=Checking result was created,
  outds=work.test_results
)

data work.assert_schema;
  length test_result $5 test_description $256 test_comments $256;
  call missing(test_result,test_description,test_comments);
  stop;
run;
%mp_assertmodel(work.test_results,base=work.assert_schema,
  desc=Checking mp_assert output schema,outds=work.schema_results)
proc append base=work.test_results data=work.schema_results;
run;
