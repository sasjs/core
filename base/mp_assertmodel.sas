/**
  @file
  @brief Temporary red-phase placeholder for mp_assertmodel

  <h4> SAS Macros </h4>
  @li mp_assert.sas
**/
%macro mp_assertmodel(inds,base=,key=,desc=,outds=work.test_results);
  %mp_assert(iftrue=(1=0),desc=&desc,outds=&outds)
%mend mp_assertmodel;
