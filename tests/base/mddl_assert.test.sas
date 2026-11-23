/**
  @file
  @brief Test the assertion result DDL and model assertion output

  <h4> SAS Macros </h4>
  @li mddl_assert.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

**/

%mddl_assert(work.assert_schema)
%mp_assert(iftrue=(%sysfunc(exist(work.assert_schema))=1),
  desc=Assertion DDL creates the requested table)

%mp_assertscope(SNAPSHOT)
%mddl_assert(work.custom_schema)
%mp_assertscope(COMPARE,desc=Assertion DDL does not leak macro variables)

/* Keep the output under test separate from the schema comparison result. */
%mp_assertmodel(work.assert_schema,base=work.assert_schema,
  desc=Create model output,outds=work.model_output)
%mp_assertmodel(work.model_output,base=work.assert_schema,
  desc=Model assertion output matches the assertion DDL)

%let ddl_syntax=%sysfunc(getoption(syntaxcheck,keyword));
options nosyntaxcheck;
%mddl_assert()
%let ddl_errorcc=&syscc;
%let syscc=0;
options &ddl_syntax;
%mp_assert(iftrue=(&ddl_errorcc>4),desc=Missing table name is rejected)
