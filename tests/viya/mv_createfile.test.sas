/**
  @file
  @brief Testing mv_createfile macro

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mfv_existfile.sas
  @li mp_assert.sas
  @li mv_createfile.sas


**/

options mprint;

%let file=%mf_uid();

%put TEST 1 - basic file upload ;
filename somefile temp;
data _null_;
  file somefile;
  put 'hello testings';
run;
%mv_createfile(path=&mcTestAppLoc/temp, name=&file..txt,inref=somefile)

%mp_assert(
  iftrue=(%mfv_existfile(&mcTestAppLoc/temp/&file..txt)=1),
  desc=Check if created file exists
)

%put TEST 2 - dataset upload ;
data temp;
x=1;
run;
filename ds "%sysfunc(pathname(work))/temp.sas7bdat";

%mv_createfile(path=&mcTestAppLoc/temp, name=&file..sas7bdat,inref=ds)

%mp_assert(
  iftrue=(%mfv_existfile(&mcTestAppLoc/temp/&file..sas7bdat)=1),
  desc=Check if created dataset exists
)