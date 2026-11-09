/**
  @file
  @brief Testing mp_unzip macro

  <h4> SAS Macros </h4>
  @li mp_unzip.sas
  @li mf_mkdir.sas
  @li mp_assert.sas

**/

%let root=%sysfunc(pathname(work))/unzip_test;
%mf_mkdir(&root)

filename zref zip "&root/test.zip";

data _null_;
  file zref member="one.txt";
  put 'zipped text';
run;

%mp_unzip(ziploc="&root/test.zip",outdir=&root/out)

%mp_assert(
  iftrue=(%sysfunc(fileexist(&root/out/one.txt))=1),
  desc=Checking that the zip member is written to the output directory,
  outds=work.test_results
)
