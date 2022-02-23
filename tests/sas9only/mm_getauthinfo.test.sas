/**
  @file
  @brief Testing mm_getauthinfo macro

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mm_getauthinfo.sas
  @li mp_assertscope.sas

**/


%mp_assertscope(SNAPSHOT)
%mm_getauthinfo(outds=auths)
%mp_assertscope(COMPARE)


%mp_assert(
  iftrue=(%mf_existds(work.auths)=1),
  desc=Check if the auths dataset was created
)