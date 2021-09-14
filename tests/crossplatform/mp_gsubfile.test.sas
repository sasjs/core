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