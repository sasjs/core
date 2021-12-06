/**
  @file
  @brief Testing mp_gsubfile.sas macro

  <h4> SAS Macros </h4>
  @li mp_init.sas
  @li mp_assert.sas

**/

/**
  * Test 1 - mp_init.sas actually already ran as part of testinit
  * So lets test to make sure it will not run again
  */

%let initial_value=&sasjs_init_num;

%mp_init();

%mp_assert(
  iftrue=("&initial_value"="&sasjs_init_num"),
  desc=Check that mp_init() did not run twice,
  outds=work.test_results
)