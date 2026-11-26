/**
  @file
  @brief Test the shared group model DDL

  <h4> SAS Macros </h4>
  @li mddl_getgroups.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas
  @li mf_nobs.sas

**/

/* This model is deliberately independent of the DDL being tested. */
data work.group_expected;
  length groupuri groupname groupdesc $256;
  stop;
run;

%mp_assertscope(SNAPSHOT)
%mddl_getgroups(work.group_schema)
%mp_assertscope(COMPARE,desc=Group DDL does not leak macro variables)
%mp_assertmodel(work.group_schema,base=work.group_expected,
  desc=Group DDL matches the fixed column contract)
%mp_assert(iftrue=(%mf_nobs(work.group_schema)=0),
  desc=Group DDL creates an empty table)
