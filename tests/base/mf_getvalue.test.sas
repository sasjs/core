/**
  @file
  @brief Testing mf_getvalue macro

  <h4> SAS Macros </h4>
  @li mf_getvalue.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

data work.test_data;
  j = "A";
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
  Get numeric value from default observation.
  Filter removes all rows. This simulates providing an empty dataset
  or specifying an observation number beyond the set returned by the filter.
  Default warn parameter setting avoids raising a w@rning.
*/
%let test_value=%mf_getvalue(work.test_data,i,filter=(i>10));
%mp_assert(
  iftrue=(&test_value=. and &syscc eq 0),
  desc=Test fetching value from 1st row of empty (filtered) data,
  outds=work.test_results
)

/* - Test 6 -
  Get numeric from default observation.
  Filter removes all rows. This simulates providing an empty dataset
  or specifying an observation number beyond the set returned by the filter.
  Explicitly raise a w@rning when reading past end of data.
*/
%let test_value=%mf_getvalue(work.test_data,i,filter=(i>10),warn=1);
%mp_assert(
  iftrue=(&test_value=. and &syscc eq 4),
  desc=Test fetching value from 1st row of empty (filtered) data,
  outds=work.test_results
)

%let syscc=0;

/* - Test 7 -
  Get character value from default observation.
  Filter removes all rows. This simulates providing an empty dataset
  or specifying an observation number beyond the set returned by the filter.
  Default warn parameter setting avoids raising a w@rning.
*/
%let test_value=%mf_getvalue(work.test_data,j,filter=(i>10));
%mp_assert(
  iftrue=(&test_value=%str() and &syscc eq 0),
  desc=Test fetching value from 1st row of empty (filtered) data,
  outds=work.test_results
)

/* - Test 8 -
  Get character value from default observation.
  Filter removes all rows. This simulates providing an empty dataset
  or specifying an observation number beyond the set returned by the filter.
  Explicitly raise a w@rning when reading past end of data.
*/
%let test_value=%mf_getvalue(work.test_data,j,filter=(i>10),warn=1);
%mp_assert(
  iftrue=(&test_value=%str() and &syscc eq 4),
  desc=Test fetching value from 1st row of empty (filtered) data,
  outds=work.test_results
)
%let syscc=0;

