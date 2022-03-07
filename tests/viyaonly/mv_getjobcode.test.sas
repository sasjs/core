/**
  @file
  @brief Testing mv_getjobcode macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createjob.sas
  @li mv_getjobcode.sas

**/

/**
  * Test Case 1
  */

/* write some code to a job */
%let incode=%str(data test; set sashelp.class;run;);
filename testref temp;
data _null_;
  file testref;
  put "&incode";
run;
%mv_createjob(
  code=testref,
  path=&mcTestAppLoc/services/temp,
  name=some_job
)

/* now get the code back */
%mp_assertscope(SNAPSHOT)
%mv_getjobcode(
  path=&mcTestAppLoc/services/temp,
  name=some_job,
  outref=mycode
)
/* exclude automatic proc json macro variables from scope check */
%mp_assertscope(COMPARE,
  ignorelist=MCLIB2_JADP1LEN MCLIB2_JADP2LEN MCLIB2_JADPNUM MCLIB2_JADVLEN
    MCLIB2_JADP3LEN
)

%let diditexist=NO;
data work.test1;
  infile mycode;
  input;
  putlog _infile_;
  line=_infile_;
  check=symget('incode');
  if _infile_=symget('incode') then call symputx('diditexist','YES');
run;

%mp_assert(
  iftrue=(&diditexist=NO),
  desc=Check if the code that was sent was successfully retrieved
)
