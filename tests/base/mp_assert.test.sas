/**
  @file
  @brief Testing mp_assert macro
  @details This is quite "meta".. it's just testing itself

  <h4> SAS Macros </h4>
  @li mddl_assert.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas

**/

%mp_assert(
  iftrue=(1=1),
  desc=Checking result was created,
  outds=work.test_results
)

%mp_assert(iftrue=(1=1),desc=Checking result was created,
  outds=work.assert_output)
%mddl_assert(work.assert_schema)
%mp_assertmodel(work.assert_output,base=work.assert_schema,
  desc=Checking mp_assert output schema)
