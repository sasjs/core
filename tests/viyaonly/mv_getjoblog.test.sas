/**
  @file
  @brief Testing mv_createwebservice macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createjob.sas
  @li mv_jobexecute.sas
  @li mv_jobwaitfor.sas
  @li mv_getjoblog.sas

**/

/**
  * Test Case 1
  */

/* create a service */
filename testref temp;
data _null_;
  file testref;
  put 'data;run;';
  put 'endsas;';
run;
%mv_createjob(
  path=&mcTestAppLoc/jobs/temp,
  code=testref,
  name=testjob
)

%* Execute it;
%mv_jobexecute(
  path=&mcTestAppLoc/jobs/temp,
  name=testjob,
  outds=work.info
)

%* Wait for it to finish;
data work.info;
  set work.info;
  where method='GET' and rel='state';
run;
%mv_jobwaitfor(ALL,inds=work.info,outds=work.jobstates)

%* and grab the uri;
data _null_;
  set work.jobstates;
  call symputx('uri',uri);
run;

%* Finally, fetch the log;
%mp_assertscope(SNAPSHOT)
%mv_getjoblog(uri=%str(&uri),outref=mylog,mdebug=1)
/* ignore auto proc json vars */
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB2_JADP2LEN MCLIB2_JADPNUM MCLIB2_JADVLEN
)

data _null_;
  infile mylog end=eof;
  input;
  putlog _infile_;
  retain found 0;
  if index(_infile_,'endsas;') then do;
    found=1;
    call symputx('found',found);
  end;
  else if eof and found ne 1 then call symputx('found',0);
run;

%mp_assert(
  iftrue=(%str(&found)=1),
  desc=Check if the log was still fetched even though endsas was submitted
)
