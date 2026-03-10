/**
  @file
  @brief Testing mm_assigndirectlib macro
  @details  A valid library must first be configured in metadata.
  To test success, also define a table for which we can test the existence.
  This is a unit test - not part of the full test run, as it would be a
  lot of overhead to create an external DB and metadata setup each time.

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mm_assigndirectlib.sas

**/

%let runtest=0;
%let libref=XXX;
%let ds=XXXX;


%mp_assertscope(SNAPSHOT)
%mm_assigndirectlib(&libref)
%mp_assertscope(COMPARE)


%mp_assert(
  iftrue=(&runtest=1 and %mf_existds(&libref..&ds)),
  desc=Check if &libref..&ds exists
)