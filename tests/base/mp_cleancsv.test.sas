/**
  @file
  @brief Testing mp_cleancsv.sas macro
  @details Credit for test 1 goes to
  [Tom](https://communities.sas.com/t5/user/viewprofilepage/user-id/159) from
  SAS Communities:
https://communities.sas.com/t5/SAS-Programming/Removing-embedded-carriage-returns/m-p/824790#M325761

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_cleancsv.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* test 1 - cope with empty rows on CR formatted file */

filename crlf "%sysfunc(pathname(work))/crlf";
filename cr "%sysfunc(pathname(work))/cr";
data _null_;
  file cr termstr=cr ;
  put 'line 1'///'line 4'/'line 5';
run;

%mp_assertscope(SNAPSHOT)
%mp_cleancsv(in=cr,out=crlf)
%mp_assertscope(COMPARE)

/* 5 rows as all converted to OD0A */
data test1;
  infile "%sysfunc(pathname(work))/crlf" lrecl=100 termstr=crlf;
  input;
  list;
run;

%put test1=%mf_nobs(test1);

%mp_assert(
  iftrue=(%mf_nobs(work.test1)=5),
  desc=Checking blank rows on CR formatted file,
  outds=work.test_results
)
