/**
  @file
  @brief Testing mp_streamfile.sas macro
  @details This is tricky to test as it streams to webout.  For now just
  check the compilation, and for macro leakage.

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_streamfile.sas

**/

%mp_assertscope(SNAPSHOT)

%mp_streamfile(iftrue=(1=0)
  ,contenttype=csv,inloc=/some/where.txt
  ,outname=myfile.txt
)

%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking error condition,
  outds=work.test_results
)

