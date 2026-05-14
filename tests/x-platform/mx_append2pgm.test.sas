/**
  @file
  @brief Testing mx_append2pgm.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_uid.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li ms_createfile.sas
  @li mv_createfile.sas
  @li mm_createstp.sas
  @li mx_append2pgm.sas
  @li mx_getcode.sas

**/

/**
  * Test 1 - Append content to an existing program and verify combined output
  * Also checking for scope leakage
  */

/* create a unique name for the program */
%let item=test_%mf_uid();

/* create the initial program with some code */
filename initpgm temp;
data _null_;
  file initpgm;
  put '%put ORIGINAL LINE;';
run;

%macro setup_pgm();
  %let platform=%mf_getplatform();
  %if &platform=SASJS %then %do;
    %ms_createfile(&mcTestAppLoc/temp/&item..sas, inref=initpgm)
  %end;
  %else %if &platform=SASVIYA %then %do;
    %mv_createfile(path=&mcTestAppLoc/temp, name=&item..sas, inref=initpgm)
  %end;
  %else %do;
    %let work=%sysfunc(pathname(work));
    data _null_;
      file "&work/&item..sas";
      infile initpgm;
      input;
      put _infile_;
    run;
    %mm_createstp(stpname=&item
      ,filename=&item..sas
      ,directory=&work
      ,tree=&mcTestAppLoc/temp
      ,stptype=2
      ,minify=NO
    )
  %end;
%mend setup_pgm;
%setup_pgm()

/* create the content to append */
filename toappnd temp;
data _null_;
  file toappnd;
  put '%put APPENDED LINE;';
run;

/* run the macro under test with scope checks */
%mp_assertscope(SNAPSHOT)
%mx_append2pgm(&mcTestAppLoc/temp/&item, inref=toappnd)
%mp_assertscope(COMPARE,
  desc=Test 1: mx_append2pgm does not leak scope,
  outds=work.test_results,
  ignorelist=MC2_JADP1LEN MC2_JADP2LEN MC2_JADPNUM MC2_JADVLEN MC2_JADP3LEN
)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Test 1: No errors after appending content to program,
  outds=work.test_results
)

/**
  * Test 2 - Verify the appended content is present
  * Fetch the modified program and check both original and appended lines exist
  */

%let test2_orig=0;
%let test2_appd=0;

%macro verify_test2();
  %let platform=%mf_getplatform();
  %if &platform=SASVIYA %then %do;
    filename verifrf filesrvc folderpath="&mcTestAppLoc/temp";
    data _null_;
      infile verifrf("&item..sas") lrecl=32000;
      input;
      if index(_infile_,'ORIGINAL LINE') then call symputx('test2_orig','1');
      if index(_infile_,'APPENDED LINE') then call symputx('test2_appd','1');
    run;
    filename verifrf clear;
  %end;
  %else %do;
    %mx_getcode(&mcTestAppLoc/temp/&item, outref=verifrf)
    data _null_;
      infile verifrf lrecl=32000;
      input;
      if index(_infile_,'ORIGINAL LINE') then call symputx('test2_orig','1');
      if index(_infile_,'APPENDED LINE') then call symputx('test2_appd','1');
    run;
  %end;
%mend verify_test2;
%verify_test2()

%mp_assert(
  iftrue=(&test2_orig=1),
  desc=Test 2a: Original content is preserved after append,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&test2_appd=1),
  desc=Test 2b: Appended content is present in modified program,
  outds=work.test_results
)

/**
  * Test 3 - Append multiple times to ensure repeated appends work
  */
filename toappd2 temp;
data _null_;
  file toappd2;
  put '%put SECOND APPEND;';
run;

%mp_assertscope(SNAPSHOT)
%mx_append2pgm(&mcTestAppLoc/temp/&item, inref=toappd2)
%mp_assertscope(COMPARE,
  desc=Test 3: mx_append2pgm does not leak scope on second call,
  outds=work.test_results
)

/* verify all three pieces of content exist */
%let test3_orig=0;
%let test3_appd=0;
%let test3_app2=0;

%macro verify_test3();
  %let platform=%mf_getplatform();
  %if &platform=SASVIYA %then %do;
    filename verifr2 filesrvc folderpath="&mcTestAppLoc/temp";
    data _null_;
      infile verifr2("&item..sas") lrecl=32000;
      input;
      if index(_infile_,'ORIGINAL LINE') then call symputx('test3_orig','1');
      if index(_infile_,'APPENDED LINE') then call symputx('test3_appd','1');
      if index(_infile_,'SECOND APPEND') then call symputx('test3_app2','1');
    run;
    filename verifr2 clear;
  %end;
  %else %do;
    %mx_getcode(&mcTestAppLoc/temp/&item, outref=verifr2)
    data _null_;
      infile verifr2 lrecl=32000;
      input;
      if index(_infile_,'ORIGINAL LINE') then call symputx('test3_orig','1');
      if index(_infile_,'APPENDED LINE') then call symputx('test3_appd','1');
      if index(_infile_,'SECOND APPEND') then call symputx('test3_app2','1');
    run;
  %end;
%mend verify_test3;
%verify_test3()

%mp_assert(
  iftrue=(&test3_orig=1),
  desc=Test 3a: Original content still present after second append,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&test3_appd=1),
  desc=Test 3b: First appended content still present after second append,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&test3_app2=1),
  desc=Test 3c: Second appended content is present,
  outds=work.test_results
)
