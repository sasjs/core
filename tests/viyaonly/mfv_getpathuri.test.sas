/**
  @file
  @brief Testing mfv_getpathuri macro function

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mfv_getpathuri.sas
  @li mp_assert.sas
  @li mv_createfile.sas

**/

options mprint sgen;

%let file=%mf_uid();

/* create a file */
filename somefile temp;
data _null_;
  file somefile;
  put 'hello testings';
run;
%let path=&mcTestAppLoc/temp;
%mv_createfile(path=&path, name=&file..txt,inref=somefile)


%mp_assert(
  iftrue=(%mfv_existfile(&path/&file..txt)=1),
  desc=Check if created file exists
)

%mp_assert(
  iftrue=(%length(%mfv_getpathuri(&path/&file..txt))>0),
  desc=Check that a URI was returned
)