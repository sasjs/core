/**
  @file
  @brief Testing mp_searchcols.sas

  <h4> SAS Macros </h4>
  @li mp_searchcols.sas
  @li mp_assertdsobs.sas


**/


/** Test 1 - full col match  */
data example1;
  var1=1;
  var2=2;
  var3=3;
data example2;
  var1=1;
  var2=2;
data example3;
  var2=2;
  var3=3;
data example4;
  matchmehere=1;
data example5;
  hereyoucan_matchme_also=1;
data example6;
  do_not_forget_me=1;
data example7;
  we_shall_not_forget=1;
run;

%mp_searchcols(libs=work,cols=var1 var2,outds=testme)

%mp_assertdsobs(work.testme,
  desc=Test1 - check exact variables are found,
  test=EQUALS 3,
  outds=work.test_results
)

/* test 2 - wildcard match */

%mp_searchcols(libs=work,cols=matchme forget,match=WILD, outds=testme2)

%mp_assertdsobs(work.testme2,
  desc=Test1 - check fuzzy matches are found,
  test=EQUALS 4,
  outds=work.test_results
)