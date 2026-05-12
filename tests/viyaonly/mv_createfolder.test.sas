/**
  @file
  @brief Testing mv_createfolder macro

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createfolder.sas
  @li mv_deleteviyafolder.sas
  @li mv_getfoldermembers.sas

**/


%let folder=%mf_uid();

/* create a folder */
%mp_assertscope(SNAPSHOT)
%mv_createfolder(path=&mcTestAppLoc/temp/&folder/&folder)
%mp_assertscope(COMPARE, ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADPNUM
  MC0_JADVLEN MC2_JADP1LEN MC2_JADP2LEN MC2_JADPNUM MC2_JADVLEN
)

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

/* create a folder without output dataset as part of the original macro */
%mv_createfolder(path=&mcTestAppLoc/temp/&folder/f2
  ,outds=folders2,mdebug=&sasjs_mdebug
)

%let test=0;
data _null_;
  set work.folders2;
  putlog (_all_)(=);
  if not missing(self_uri) then call symputx('test2',1);
run;

%mp_assert(
  iftrue=(&test2=1),
  desc=Check if outds param works
)

/* create a folder with full stops */
%let newfolder=%mf_uid().2.1;
%mv_createfolder(path=&mcTestAppLoc/temp/&newfolder
  ,outds=work.folders3
  ,mdebug=&sasjs_mdebug
)

%mv_getfoldermembers(root=&mcTestAppLoc/temp, outds=work.folders3)

%let test3=0;
data _null_;
  set work.folders3;
  putlog (_all_)(=);
  if name="&newfolder" then call symputx('test3',1);
run;

%mp_assert(
  iftrue=(&test3=1),
  desc=Check if folder with full stops can be successfully created
)