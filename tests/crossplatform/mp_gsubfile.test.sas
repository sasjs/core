/**
  @file
  @brief Testing mp_gsubfile.sas macro

  <h4> SAS Macros </h4>
  @li mp_gsubfile.sas
  @li mp_assert.sas

**/

/**
  * test 1 - simple replace
  */
%global str1;
%let file=%sysfunc(pathname(work))/file.txt;
%let pat=replace/me;
%let str=with/this;
data _null_;
  file "&file";
  put "&pat";
run;
%mp_gsubfile(file=&file, patternvar=pat, replacevar=str)
data _null_;
  infile "&file";
  input;
  call symputx('str1',_infile_);
run;

%mp_assert(
  iftrue=("&str1"="&str"),
  desc=Check that simple replacement was successful,
  outds=work.test_results
)

/**
  * test 2 - replace from additional line
  */
%global str2 strcheck2 strcheck2b;
%let file2=%sysfunc(pathname(work))/file2.txt;
%let pat2=replace/me;
%let str2=with/this;
data _null_;
  file "&file2";
  put 'line1';output;
  put "&pat2";output;
  put "&pat2";output;
run;
%mp_gsubfile(file=&file2, patternvar=pat2, replacevar=str2)
data _null_;
  infile "&file2";
  input;
  if _n_=2 then call symputx('strcheck2',_infile_);
  if _n_=3 then call symputx('strcheck2b',_infile_);
  putlog _infile_;
run;

%mp_assert(
  iftrue=("&strcheck2"="&str2"),
  desc=Check that multi line replacement was successful (line2),
  outds=work.test_results
)
%mp_assert(
  iftrue=("&strcheck2b"="&str2"),
  desc=Check that multi line replacement was successful (line3),
  outds=work.test_results
)