/**
  @file
  @brief Testing mx_createjob.sas macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mx_createjob.sas
  @li mp_assert.sas

**/

filename ft15f001 temp;
parmcards4;
  data example1;
    set sashelp.class;
  run;
  %put Job executed successfully;
;;;;
%mx_createjob(path=&mcTestAppLoc/jobs,name=testjob,replace=YES)

%mp_assert(
  iftrue=(&syscc=0),
  desc=No errors after job creation,
  outds=work.test_results
)
