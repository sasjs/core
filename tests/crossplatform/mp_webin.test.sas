/**
  @file
  @brief Testing mp_webin macro

  <h4> SAS Macros </h4>
  @li mp_webin.sas
  @li mp_assert.sas

**/

/* force SAS9 tests as we don't have a valid URI available */
%macro mf_getplatform();
  SAS9
%mend mf_getplatform;

/* TEST 1 */
%let _webin_file_count=1;
%let _webin_filename=test;
%mp_webin()

%mp_assert(
  iftrue=(
    %symexist(_WEBIN_FILEREF1)
  ),
  desc=Checking if the macvar exists,
  outds=work.test_results
)

/* TEST 2 */
%global _WEBIN_FILENAME1;
%mp_assert(
  iftrue=(
    %str(&_WEBIN_FILENAME1)=%str(test)
  ),
  desc=Checking if the macvar exists,
  outds=work.test_results
)


