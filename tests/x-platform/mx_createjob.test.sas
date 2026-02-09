/**
  @file
  @brief Testing mx_createjob.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mx_createjob.sas
  @li mp_assert.sas
  @li mf_getuniquefileref.sas
  @li mp_assertscope.sas

**/

/**
  * Test 1 - Basic job creation with default parameters
  * Also checking for scope leakage
  */
filename ft15f001 temp;
parmcards4;
  data example1;
    set sashelp.class;
  run;
  %put Job executed successfully;
;;;;
%mp_assertscope(SNAPSHOT)
%mx_createjob(path=&mcTestAppLoc/jobs,name=testjob1,replace=YES)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 1: No errors after basic job creation,
  outds=work.test_results
)

/**
  * Test 2 - Job creation with custom description
  */
filename ft15f001 temp;
parmcards4;
  data example2;
    set sashelp.cars;
  run;
;;;;
%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob2,
  desc=Custom job description for testing,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 2: Job created with custom description,
  outds=work.test_results
)

/**
  * Test 3 - Job creation with precode
  */
filename precode1 temp;
data _null_;
  file precode1;
  put '%let testvar=PreCodeValue;';
  put '%put &=testvar;';
run;

filename ft15f001 temp;
parmcards4;
  data example3;
    set sashelp.class;
    precode_var="&testvar";
  run;
;;;;
%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob3,
  precode=precode1,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 3: Job created with precode parameter,
  outds=work.test_results
)

filename precode1 clear;

/**
  * Test 4 - Job creation with multiple code filerefs
  */
%let code1=%mf_getuniquefileref();
%let code2=%mf_getuniquefileref();

filename &code1 temp;
data _null_;
  file &code1;
  put 'data work.part1;';
  put '  set sashelp.class(obs=5);';
  put 'run;';
run;

filename &code2 temp;
data _null_;
  file &code2;
  put 'data work.part2;';
  put '  set sashelp.class(firstobs=6);';
  put 'run;';
run;

%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob4,
  code=&code1 &code2,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 4: Job created with multiple code filerefs,
  outds=work.test_results
)

filename &code1 clear;
filename &code2 clear;

/**
  * Test 5 - Job creation with both precode and multiple code files
  */
%let pre1=%mf_getuniquefileref();
%let pre2=%mf_getuniquefileref();
%let main1=%mf_getuniquefileref();

filename &pre1 temp;
data _null_;
  file &pre1;
  put '%let globalvar1=Value1;';
run;

filename &pre2 temp;
data _null_;
  file &pre2;
  put '%let globalvar2=Value2;';
run;

filename &main1 temp;
data _null_;
  file &main1;
  put 'data work.combined;';
  put '  var1="&globalvar1";';
  put '  var2="&globalvar2";';
  put '  output;';
  put 'run;';
run;

%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob5,
  precode=&pre1 &pre2,
  code=&main1,
  desc=Job with multiple precode and code files,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 5: Job created with multiple precode and code files,
  outds=work.test_results
)

filename &pre1 clear;
filename &pre2 clear;
filename &main1 clear;

/**
  * Test 6 - Job creation with special characters in code
  */
filename ft15f001 temp;
parmcards4;
  data example6;
    length text $200;
    text='Special chars: & % $ # @ !';
    output;
    text="Quotes: 'single' and ""double""";
    output;
  run;
  %put Test with special characters;
;;;;
%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob6,
  desc=Job with special characters in code,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 6: Job created with special characters in code,
  outds=work.test_results
)

/**
  * Test 7 - Job creation with macro code
  */
filename ft15f001 temp;
parmcards4;
  %macro testmacro();
    data example7;
      set sashelp.class;
      where age > 12;
    run;
  %mend testmacro;

  %testmacro()
;;;;
%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob7,
  desc=Job containing macro definitions,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 7: Job created with macro code,
  outds=work.test_results
)

/**
  * Test 8 - Job creation with empty code (edge case)
  */
filename ft15f001 temp;
data _null_;
  file ft15f001;
  put '/* Empty job for testing */';
run;

%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob8,
  desc=Job with minimal code,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 8: Job created with minimal code,
  outds=work.test_results
)

/**
  * Test 9 - Job creation with long code block
  */
filename ft15f001 temp;
data _null_;
  file ft15f001;
  put 'data work.longtest;';
  do i=1 to 50;
    put '  var' i +(-1) '=' i ';';
  end;
  put '  output;';
  put 'run;';
run;

%mx_createjob(
  path=&mcTestAppLoc/jobs,
  name=testjob9,
  desc=Job with many variables,
  replace=YES
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 9: Job created with long code block,
  outds=work.test_results
)

/**
  * Test 10 - Replace existing job (replace=YES)
  */
filename ft15f001 temp;
parmcards4;
  data example10_v1;
    set sashelp.class;
  run;
;;;;
%mx_createjob(path=&mcTestAppLoc/jobs,name=testjob10,replace=YES)

/* Now replace it */
filename ft15f001 temp;
parmcards4;
  data example10_v2;
    set sashelp.cars;
  run;
;;;;
%mx_createjob(path=&mcTestAppLoc/jobs,name=testjob10,replace=YES)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 10: Job replaced successfully with replace=YES,
  outds=work.test_results
)
