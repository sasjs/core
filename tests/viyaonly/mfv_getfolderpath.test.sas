/**
  @file
  @brief Testing mfv_getfolderpath macro function

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mfv_getfolderpath.sas
  @li mfv_getpathuri.sas
  @li mp_assert.sas
  @li mv_createfolder.sas

**/

options mprint sgen;

%let folder=%mf_uid();
/* create a folder */
%mv_createfolder(path=&mcTestAppLoc/&folder)
%mp_assert(
  iftrue=(&syscc=0),
  desc=no errs on folder creation
)

%let uri=%mfv_getpathuri(&mcTestAppLoc/&folder);
%put %mfv_getfolderpath(&uri);

%mp_assert(
  iftrue=("%mfv_getfolderpath(&uri)"="&mcTestAppLoc/&folder"),
  desc=Check if correct folder was returned
)

