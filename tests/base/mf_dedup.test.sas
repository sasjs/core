/**
  @file
  @brief Testing mf_dedup macro

  <h4> SAS Macros </h4>
  @li mf_dedup.sas
  @li mp_assert.sas

**/

%let str=One two one two and through and through;

%mp_assert(
  iftrue=("%mf_dedup(&str)"="One two one and through"),
  desc=Basic test,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_dedup(&str,outdlm=%str(,))"="One,two,one,and,through"),
  desc=Outdlm test,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_dedup(alpha|beta|gamma,indlm=%str(|))"="alpha beta gamma"),
  desc=Input delimiter test,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_dedup(alpha|beta|alpha|gamma,indlm=%str(|))"="alpha beta gamma"),
  desc=Input delimiter duplicate test,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_dedup(alpha|beta|alpha|gamma,indlm=%str(|),outdlm=%str(,))"
    ="alpha,beta,gamma"),
  desc=Input and output delimiter duplicate test,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_dedup(alpha beta gamma)"="alpha beta gamma"),
  desc=Final unique word test,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_dedup(alpha)"="alpha"),
  desc=Single word test,
  outds=work.test_results
)
