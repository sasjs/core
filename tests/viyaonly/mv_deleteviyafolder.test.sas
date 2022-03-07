/**
  @file
  @brief Testing mv_deleteviyafolder macro function

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mfv_existfolder.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createfolder.sas
  @li mv_deleteviyafolder.sas

**/

options mprint sgen;

%let folder=%mf_uid();
%let tgtfolder=&mcTestAppLoc/temp/&folder;

/* create a folder */
%mv_createfolder(path=&tgtfolder)


%mp_assert(
  iftrue=(%mfv_existfolder(&tgtfolder)=1),
  desc=Check if created folder exists
)

%mp_assertscope(SNAPSHOT)
%mv_deleteviyafolder(path=&tgtfolder)
/* ignore proc json vars */
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB0_JADP1LEN MCLIB0_JADP2LEN MCLIB0_JADVLEN MCLIB2_JADP1LEN
    MCLIB2_JADVLEN
)

%mp_assert(
  iftrue=(%mfv_existfolder(&tgtfolder)=0),
  desc=Check if deleted folder is gone
)

/* delete folder with content */
%mv_createfolder(path=&tgtfolder/content/and/stuff)
%mp_assert(
  iftrue=(%mfv_existfolder(&tgtfolder/content/and/stuff)=1),
  desc=Check if folder with content exists
)
%mv_deleteviyafolder(path=&tgtfolder)
%mp_assert(
  iftrue=(%mfv_existfolder(&tgtfolder)=0),
  desc=Check if deleted folder with subfolders is gone
)
