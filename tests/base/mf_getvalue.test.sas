/**
  @file
  @brief Testing mf_getvalue macro

  <h4> SAS Macros </h4>
  @li mf_getvalue.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.test_data;
  do i = 1 to 10;
    output;
  end;
  stop;
run;

/* - Test 1 -
  Get value from default first observation.
  No filter.
*/
%mp_assertscope(SNAPSHOT)
%let test_value=%mf_getvalue(work.test_data,i);
%mp_assertscope(COMPARE,ignorelist=test_value)

%mp_assert(
  iftrue=(&test_value=1 and &syscc eq 0),
  desc=Basic test fetching value from default first obs,
  outds=work.test_results
)

/* - Test 2 -
  Get value from 10th observation.
  No filter.
*/
%let test_value=%mf_getvalue(work.test_data,i,fetchobs=10);
%mp_assert(
  iftrue=(&test_value=10 and &syscc eq 0),
  desc=Test fetching value from specifically the 10th row,
  outds=work.test_results
)

/* - Test 3 -
  Get value from default first observation.
  With filter.
*/
%let test_value=%mf_getvalue(work.test_data,i,filter=(i>4));
%mp_assert(
  iftrue=(&test_value=5 and &syscc eq 0),
  desc=Test fetching value from default row of filtered data,
  outds=work.test_results
)

/* - Test 4 -
  Get value from specified observation.
  With filter.
*/
%let test_value=%mf_getvalue(work.test_data,i,filter=(i>4),fetchobs=5);
%mp_assert(
  iftrue=(&test_value=9 and &syscc eq 0),
  desc=Test fetching value from 5th row of filtered data,
  outds=work.test_results
)

/* - Test 5 -
  Get value from default observation.
  Filter removes all rows. This simulates providing an empty dataset
  or specifying an observation number beyond the set returned by the filter.
*/
%let test_value=%mf_getvalue(work.test_data,i,filter=(i>10));
%mp_assert(
  iftrue=(&test_value=%str() and &syscc eq 4),
  desc=Test fetching value from 1st row of empty (filtered) data,
  outds=work.test_results
)

%let syscc = 0; /* Reset w@rning To ensure confidence in next test */

/* - Test 6 -
  Get value from default observation.
  Dataset does not exist.
*/
%let test_value=%mf_getvalue(work.test_data_x,i);
%mp_assert(
  iftrue=(&test_value=%str() and &syscc gt 0),
  desc=Test fetching value from 1st row of non-existent data,
  outds=work.test_results
)

%let syscc = 0; /* To reset expected error and allow test job to exit clean. */
