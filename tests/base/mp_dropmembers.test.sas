/**
  @file
  @brief Testing mp_dropmembers macro

  <h4> SAS Macros </h4>
  @li mp_dropmembers.sas
  @li mf_existds.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.drop_scope work.drop_a work.drop_b work.drop_keep1
  work.drop_keep2;
  x=1;
  output;
run;

/* mp_dropmembers emits statements, so it is called in open code rather
  than inside a %put */
%mp_assertscope(SNAPSHOT)
%mp_dropmembers(list=drop_scope)
%mp_assertscope(COMPARE,
  desc=Checking that mp_dropmembers does not leak scope,
  outds=work.test_results
)

%mp_dropmembers(list=drop_a)

%mp_assert(
  iftrue=(%mf_existds(work.drop_a)=0),
  desc=Checking that a listed dataset is dropped,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existds(work.drop_b)=1),
  desc=Checking that an unlisted dataset is kept,
  outds=work.test_results
)

/* a false condition leaves the library untouched */
%mp_dropmembers(list=drop_keep1,iftrue=(1=0))
%mp_assert(
  iftrue=(%mf_existds(work.drop_keep1)=1),
  desc=Checking that a false iftrue condition drops nothing,
  outds=work.test_results
)

/* a true condition still drops the member */
%mp_dropmembers(list=drop_keep2,iftrue=(1=1))
%mp_assert(
  iftrue=(%mf_existds(work.drop_keep2)=0),
  desc=Checking that a true iftrue condition drops the member,
  outds=work.test_results
)
