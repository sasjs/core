/**
  @file
  @brief Test the assertion result DDL and model assertion output

  <h4> SAS Macros </h4>
  @li mddl_assert.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

**/

/* Test the default before any assertions create work.test_results. */
%mddl_assert()
%mp_assert(iftrue=(%sysfunc(exist(work.test_results))=1),
  desc=Assertion DDL creates the default result table)

%mp_assertscope(SNAPSHOT)
%mddl_assert(libds=work.assert_schema)
%mp_assertscope(COMPARE,desc=Assertion DDL does not leak macro variables)

/* Independent of mp_assertmodel, check all names, types and lengths. */
proc sql noprint;
  select count(*), sum(
    (upcase(name)='TEST_DESCRIPTION' and type='char' and length=256) or
    (upcase(name)='TEST_RESULT' and type='char' and length=5) or
    (upcase(name)='TEST_COMMENTS' and type='char' and length=256)
  ) into :ddl_columns trimmed, :ddl_matched trimmed
  from dictionary.columns
  where libname='WORK' and memname='ASSERT_SCHEMA';
  select count(*) into :ddl_rows trimmed from work.assert_schema;
  select sum((varnum=1 and upcase(name)='TEST_DESCRIPTION') or
    (varnum=2 and upcase(name)='TEST_RESULT') or
    (varnum=3 and upcase(name)='TEST_COMMENTS')) into :ddl_order trimmed
  from dictionary.columns
  where libname='WORK' and memname='ASSERT_SCHEMA';
  select count(*), sum(
    (upcase(name)='TEST_DESCRIPTION' and type='char' and length=256) or
    (upcase(name)='TEST_RESULT' and type='char' and length=5) or
    (upcase(name)='TEST_COMMENTS' and type='char' and length=256)
  ) into :default_columns trimmed, :default_matched trimmed
  from dictionary.columns
  where libname='WORK' and memname='TEST_RESULTS';
quit;
%mp_assert(iftrue=(&default_columns=3 and &default_matched=3),
  desc=Default assertion table has the expected schema)
%mp_assert(iftrue=(&ddl_columns=3 and &ddl_matched=3 and &ddl_rows=0),
  desc=Assertion DDL creates an empty table with the expected schema)
%mp_assert(iftrue=(&ddl_order=3),
  desc=Assertion DDL preserves canonical column order)

/* Start with no destination so the macro itself must create its schema. */
%mp_assertmodel(work.assert_schema,base=work.assert_schema,
  desc=Fresh output,outds=work.model_output)
proc sql noprint;
  select count(*), sum(
    (upcase(name)='TEST_DESCRIPTION' and type='char' and length=256) or
    (upcase(name)='TEST_RESULT' and type='char' and length=5) or
    (upcase(name)='TEST_COMMENTS' and type='char' and length=256)
  ) into :model_columns trimmed, :model_matched trimmed
  from dictionary.columns
  where libname='WORK' and memname='MODEL_OUTPUT';
  select sum((varnum=1 and upcase(name)='TEST_DESCRIPTION') or
    (varnum=2 and upcase(name)='TEST_RESULT') or
    (varnum=3 and upcase(name)='TEST_COMMENTS')) into :model_order trimmed
  from dictionary.columns
  where libname='WORK' and memname='MODEL_OUTPUT';
  select count(*), sum(test_description='Fresh output' and test_result='PASS'
    and test_comments='Column names types and lengths match')
    into :model_rows trimmed, :model_row_matches trimmed
  from work.model_output;
quit;
%mp_assert(iftrue=(&model_columns=3 and &model_matched=3 and &model_rows=1
    and &model_row_matches=1),
  desc=Model assertion creates the expected output schema and row)
%mp_assert(iftrue=(&model_order=3),
  desc=Fresh model assertion output preserves canonical column order)

/* Check against the DDL as well as independently above. */
%mp_assertmodel(work.model_output,base=work.assert_schema,
  desc=Output matches DDL,outds=work.schema_check)
proc sql noprint;
  select count(*), sum(test_result='PASS') into :check_rows trimmed,
    :check_pass trimmed from work.schema_check;
quit;
%mp_assert(iftrue=(&check_rows=1 and &check_pass=1),
  desc=Model assertion output matches the canonical model)

/* Existing assertion tables have a different column order. */
%mp_assert(iftrue=(1=1),desc=Existing row,outds=work.append_output)
%mp_assertmodel(work.assert_schema,base=work.assert_schema,
  desc=Appended row,outds=work.append_output)
proc sql noprint;
  select count(*), sum(test_description='Existing row' and test_result='PASS'),
    sum(test_description='Appended row' and test_result='PASS')
    into :append_rows trimmed, :old_row trimmed, :new_row trimmed
  from work.append_output;
quit;
%mp_assert(iftrue=(&append_rows=2 and &old_row=1 and &new_row=1),
  desc=Model assertion appends to existing generic assertion output)

/* A precreated canonical table accepts results from both macros. */
%mddl_assert(libds=work.canonical_output)
%mp_assertmodel(work.assert_schema,base=work.assert_schema,
  desc=Model row,outds=work.canonical_output)
%mp_assert(iftrue=(1=1),desc=Generic row,outds=work.canonical_output)
proc sql noprint;
  select count(*), sum(test_description='Model row' and test_result='PASS'),
    sum(test_description='Generic row' and test_result='PASS')
    into :canonical_rows trimmed, :model_row trimmed, :generic_row trimmed
  from work.canonical_output;
quit;
%mp_assert(iftrue=(&canonical_rows=2 and &model_row=1 and &generic_row=1),
  desc=Canonical table accepts model and generic assertions)
