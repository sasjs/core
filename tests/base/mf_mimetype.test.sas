/**
  @file
  @brief Testing mf_mimetype macro

  <h4> SAS Macros </h4>
  @li mf_mimetype.sas
  @li mp_assert.sas

**/


%mp_assert(
  iftrue=("%mf_mimetype(XLS)"="application/vnd.ms-excel",
  desc=Checking correct value
)

