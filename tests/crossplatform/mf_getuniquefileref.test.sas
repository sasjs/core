/**
  @file
  @brief Testing mf_getuniquefileref macro
  @details To test performance you can also use the following macro:

      %macro x(prefix);
      %let now=%sysfunc(datetime());
      %do x=1 %to 1000;
        %let rc=%mf_getuniquefileref(prefix=&prefix);
      %end;
      %put %sysevalf(%sysfunc(datetime())-&now);
      %mend;
      %x(_)
      %x(0)

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(
    "%substr(%mf_getuniquefileref(prefix=0),1,1)"="#"
  ),
  desc=Checking for a natively assigned fileref,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%substr(%mf_getuniquefileref(),1,1)"="_"
  ),
  desc=Checking for a default fileref,
  outds=work.test_results
)
