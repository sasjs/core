/**
  @file
  @brief Testing ms_getusers.sas macro

  <h4> SAS Macros </h4>
  @li ms_getusers.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/


%mp_assertscope(SNAPSHOT)
%ms_getusers(outds=work.test1,mdebug=&sasjs_mdebug)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADPNUM MCLIB0_JADVLEN
)

%mp_assertdsobs(work.test1,test=ATLEAST 1)




