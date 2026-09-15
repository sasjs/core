/**

  @file
  @brief Testing mv_jobflow macro
  @details A job parameter value may contain any character.  A value holding a
  double quote is escaped when the paramstring is built, and the escaping shifts
  how the macro processor pairs quotes - a single quote in the value then reads
  as an unterminated literal and stops the flow.  The flow must still submit the
  job, and the value must arrive in the child session intact.

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mv_createjob.sas
  @li mv_jobflow.sas

**/

/**
  * Test Case 1 - parameter value with a double quote and an odd number of
  * single quotes
  */

data _null_;
  length v $200;
  dq=byte(34);
  v=cats(dq,"'=the formula with leading apostrophe",dq);
  call symputx('quoteval',v);
run;

filename testprog temp;
data _null_;
  file testprog;
  put 'data _null_;'
  /   '  x=symget("quoteval");'
  /   '  put "received: " x;'
  /   'run;'
  ;
run;

%mv_createjob(path=&mcTestAppLoc,name=quotejob,code=testprog)

data work.inputjobs;
  _contextName="&mcTestContext";
  _program="&mcTestAppLoc/quotejob";
  quoteval=symget('quoteval');
run;

* Trigger the flow ;

%mv_jobflow(inds=work.inputjobs
  ,maxconcurrency=1
  ,outds=work.results
  ,outref=myjoblog
  ,raise_err=1
  ,mdebug=1
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking the flow runs when a parameter value has an odd number of quotes
)

data _null_;
  infile myjoblog end=eof;
  retain found 0;
  input;
  if index(_infile_,"the formula with leading apostrophe") then found=1;
  if eof then call symputx('foundval',found);
run;

%mp_assert(
  iftrue=(&foundval=1),
  desc=Checking the parameter value arrived in the child job
)
