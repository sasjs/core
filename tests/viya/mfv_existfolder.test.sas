/**
  @file
  @brief Testing mfv_existfolder macro function

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mfv_existfolder.sas
  @li mp_assert.sas
  @li mv_createfolder.sas

**/

options mprint sgen;

%let folder=%mf_uid();

/* create a folder */
%mv_createfolder(path=&mcTestAppLoc/temp/&folder)


%mp_assert(
  iftrue=(%mfv_existfolder(&mcTestAppLoc/temp/&folder)=1),
  desc=Check if created folder exists
)

%mp_assert(
  iftrue=(%mfv_existfolder(&mcTestAppLoc/temp/&folder/%mf_uid()/noway)=0),
  desc=Check if non created folder does not exist
)