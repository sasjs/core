/**
  @file
  @brief Testing mf_deletefile.sas macro

  <h4> SAS Macros </h4>
  @li mf_deletefile.sas
  @li mf_writefile.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%let test1file=&sasjswork/myfile1.txt;

%mf_writefile(&test1file,l1=some content)

%mp_assert(
  iftrue=(%sysfunc(fileexist(&test1file))=1),
  desc=Check &test1file exists
)

%mp_assertscope(SNAPSHOT)
%mf_deletefile(&test1file)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(%sysfunc(fileexist(&test1file))=0),
  desc=Check &test1file no longer exists
)
