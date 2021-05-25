/**
  @file
  @brief Testing mv_createfolder macro

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mv_createfolder.sas
  @li mv_deleteviyafolder.sas
  @li mv_getfoldermembers.sas

**/


%let folder=%mf_uid();

/* create a folder */
%mv_createfolder(path=&mcTestAppLoc/temp/&folder/&folder)

%mv_getfoldermembers(root=&mcTestAppLoc/temp/&folder, outds=work.folders)

%let test=0;
data _null_;
  set work.folders;
  putlog (_all_)(=);
  if name="&folder" then call symputx('test',1);
run;

%mp_assert(
  iftrue=(&test=1),
  desc=Check if temp folder can be successfully created
)