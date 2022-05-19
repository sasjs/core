/**
  @file
  @brief Testing mp_getformats.sas macro

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mp_getformats.sas
  @li mp_assert.sas

**/

/**
  * Test - setup
  */

%mf_mkdir(&sasjswork/path1)
%mf_mkdir(&sasjswork/path2)

libname path1 "&sasjswork/path1";
libname path2 "&sasjswork/path2";


PROC FORMAT library=path1;
  value whichpath 0 = 'path1' other='big fat problem if not path1';
PROC FORMAT library=path2;
  value whichpath 0 = 'path2' other='big fat problem if not path2';
RUN;


/** run with path1 path2 FMTSEARCH */
options insert=(fmtsearch=(path1 path2));
data _null_;
  test=0;
  call symputx('test1',put(test,whichpath.));
run;
%mp_assert(
  iftrue=("&test1"="path1"),
  desc=Check correct format is applied,
  outds=work.test_results
)
%mp_getformats(fmtlist=WHICHPATH,outsummary=sum,outdetail=detail1)
%let tst1=0;
data _null_;
  set detail1;
  if fmtname='WHICHPATH' and start='**OTHER**' then call symputx('tst1',label);
  putlog (_all_)(=);
run;
%mp_assert(
  iftrue=("&tst1"="big fat problem if not path1"),
  desc=Check correct detail results are applied,
  outds=work.test_results
)

/** run with path2 path1 FMTSEARCH */
options insert=(fmtsearch=(path2 path1));
data _null_;
  test=0;
  call symputx('test2',put(test,whichpath.));
run;
%mp_assert(
  iftrue=("&test2"="path2"),
  desc=Check correct format is applied,
  outds=work.test_results
)
%mp_getformats(fmtlist=WHICHPATH,outsummary=sum,outdetail=detail2)
%let tst2=0;
data _null_;
  set detail2;
  if fmtname='WHICHPATH' and start='**OTHER**' then call symputx('tst2',label);
  putlog (_all_)(=);
run;
%mp_assert(
  iftrue=("&tst2"="big fat problem if not path2"),
  desc=Check correct detail results are applied,
  outds=work.test_results
)