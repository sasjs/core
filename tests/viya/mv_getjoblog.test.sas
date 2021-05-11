/**
  @file
  @brief Testing mv_createwebservice macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
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
%mv_getjoblog(uri=%str(&uri),outref=mylog)


data _null_;
  infile mylog;
  input;
  if index(_infile_,'endsas;') then call symputx('found',1);
  else call symputx('found',0);
run;

%mp_assert(
  iftrue=(%str(&found)=1),
  desc=Check if the log was still fetched even though endsas was submitted
)