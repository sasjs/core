/**
  @file
  @brief Testing mv_jobflow macro
  @details All jobs complete successfully with syscc = 0 - test to
  make sure this comes back to the calling session
​
  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mv_createjob.sas
  @li mv_jobflow.sas
**/

/**
  * Test Case 1
  */
filename testprog temp;
data _null_;
  file testprog;
  put '%put this is job: &_program;'
  /   '%put this was run in flow &flow_id;'
  /   'data ;'
  /   '  rval=rand("uniform");'
  /   '  rand=rval*&macrovar1;'
  /   '  do x=1 to rand;'
  /   '    y=rand*&macrovar2;'
  /   '    output;'
  /   '  end;'
  /   'run;'
  ;
run;

%mv_createjob(path=/Public/temp,name=demo1,code=testprog)
%mv_createjob(path=/Public/temp,name=demo2,code=testprog)

data work.inputjobs;
  _contextName='SAS Job Execution compute context';
  do flow_id=1 to 2;
    do i=1 to 4;
      _program='/Public/temp/demo1';
      macrovar1=10*i;
      macrovar2=4*i;
      output;
      i+1;
      _program='/Public/temp/demo2';
      macrovar1=40*i;
      macrovar2=44*i;
      output;
    end;
  end;
run;

* Trigger the flow ;

%put NOTE: &=syscc;

%mv_jobflow(inds=work.inputjobs
  ,maxconcurrency=2
  ,outds=work.results
  ,outref=myjoblog
  ,raise_err=1
  ,mdebug=1
)

%put NOTE: &=syscc;

data _null_;
  infile myjoblog;
  input; put _infile_;
run;

%mp_assert(
  iftrue=(&syscc eq 0),
  desc=Check that a zero return code is returned if no called job fails
)
