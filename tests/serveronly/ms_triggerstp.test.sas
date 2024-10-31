/**
  @file
  @brief Testing ms_triggerstp.sas macro

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li ms_createfile.sas
  @li ms_triggerstp.sas
  @li mf_existds.sas
  @li mp_assertdsobs.sas
  @li mp_assertcols.sas
  @li mf_getvartype.sas
  @li ms_deletefile.sas

**/

/* first, create multiple STPs to run */
filename stpcode1 temp;
data _null_;
  file stpcode1;
  put '%put hello world;';
  put '%put _all_;';
  put 'data _null_; file _webout1; put "triggerstp test 1";run;';
run;
filename stpcode2 temp;
data _null_;
  file stpcode2;
  put '%put Lorem Ipsum;';
  put '%put _all_;';
  put 'data _null_; file _webout2; put "triggerstp test 2";run;';
run;
options mprint;
%let fname1=%mf_getuniquename();
%let fname2=%mf_getuniquename();

%ms_createfile(/sasjs/tests/&fname1..sas
  ,inref=stpcode1
  ,mdebug=1
)
%ms_createfile(/sasjs/tests/&fname2..sas
  ,inref=stpcode2
)

%mp_assertscope(SNAPSHOT)
  %ms_triggerstp(/sasjs/tests/&fname1
    ,debug=131
    ,outds=work.mySessions
  )
  %ms_triggerstp(/sasjs/tests/&fname2
    ,outds=work.mySessions
  )
%mp_assertscope(COMPARE
                ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADPNUM MCLIB0_JADVLEN)

%mp_assert(iftrue=%str(%mf_existds(work.mySessions)=1)
          ,desc=Testing output exists
          ,outds=work.test_results
)

%mp_assertdsobs(work.mySessions,
  test=EQUALS 2,
  desc=Testing observations,
  outds=work.test_results
)
%mp_assertcols(work.mySessions,
  cols=sessionid,
  test=ALL,
  desc=Testing column exists,
  outds=work.test_results
)

data _null_;
  retain contentCheck 1;
  set work.mySessions end=last;
  if missing(sessionID) then contentCheck = 0;
  if last then do;
    call symputx("contentCheck",contentCheck,"l");
  end;
run;
%let typeCheck = %mf_getvartype(work.mySessions,sessionid);

%mp_assert(iftrue=%str(&typeCheck = C and &contentCheck = 1)
          ,desc=Testing type and content of output
          ,outds=work.test_results
)

%ms_deletefile(/sasjs/tests/&fname1..sas)
%ms_deletefile(/sasjs/tests/&fname2..sas)