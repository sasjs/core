/**
  @file
  @brief Testing mf_trimstr.sas macro

  <h4> SAS Macros </h4>
  @li mf_trimstr.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)

/* the three examples in the macro's own documentation */
%mp_assert(
  iftrue=("%mf_trimstr(/blah/,/)"="/blah"),
  desc=Removes a trailing slash,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_trimstr(/blah/,h)"="/blah/"),
  desc=Leaves a value whose tail does not match alone,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_trimstr(/blah/,h/)"="/bla"),
  desc=Removes a two character tail,
  outds=work.test_results
)

/* a value shorter than the trim string cannot end with it, so nothing is
  removed - this used to return an empty string, which lost the value */
%mp_assert(
  iftrue=("%mf_trimstr(ab,xyz)"="ab"),
  desc=Returns a value shorter than the trim string unchanged,
  outds=work.test_results
)

/* a value equal to the trim string is entirely a tail, so it goes */
%mp_assert(
  iftrue=("%mf_trimstr(abc,abc)"=""),
  desc=Removes a value that is exactly the trim string,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_trimstr(,xyz)"=""),
  desc=An empty value stays empty,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_trimstr(aaaXYZ,XYZ)"="aaa"),
  desc=Removes a multi character tail,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_trimstr(x,x)"=""),
  desc=A single character matching the trim string is removed,
  outds=work.test_results
)

%mp_assertscope(COMPARE)
