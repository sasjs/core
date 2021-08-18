/**
  @file
  @brief Testing mcf_stpsrv_header macro

  <h4> SAS Macros </h4>
  @li mcf_stpsrv_header.sas
  @li mp_assert.sas

**/

%let sasjs_stpsrv_header_loc=%sysfunc(pathname(work))/stpsrv_header.txt;

%mcf_stpsrv_header(wrap=YES, insert_cmplib=YES)

data _null_;
  rc=stpsrv_header('Content-type','application/text');
  rc=stpsrv_header('Content-disposition',"attachment; filename=file.txt");
run;

%let test1=FAIL;
%let test2=FAIL;

data _null_;
  infile "&sasjs_stpsrv_header_loc";
  input;
  if _n_=1 and _infile_='Content-type: application/text'
  then call symputx('test1','PASS');
  else if _n_=2 & _infile_='Content-disposition: attachment; filename=file.txt'
  then call symputx('test2','PASS');
run;

%mp_assert(
  iftrue=(%str(&test1)=%str(PASS)),
  desc=Check first header line
)
%mp_assert(
  iftrue=(%str(&test2)=%str(PASS)),
  desc=Check second header line
)