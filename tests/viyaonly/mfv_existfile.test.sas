/**
  @file
  @brief Testing mfv_existfile macro function

  <h4> SAS Macros </h4>
  @li mf_uid.sas
  @li mfv_existfile.sas
  @li mp_assert.sas
  @li mv_createfile.sas

**/

options mprint sgen;

%let file=%mf_uid();

/* create a folder */
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

%mp_assert(
  iftrue=(%mfv_existfile(&mcTestAppLoc/temp/%mf_uid().txt)=0),
  desc=Check if non created file does not exist
)

/* the syscc guard: a dirty syscc must not be reported as a genuine miss, and
  must not break the =1 comparison the callers use.  The call is made outside
  the assert so the logged err line does not land inside the assert's step. */
%let syscc=1012;
%let guard_ret=%mfv_existfile(&mcTestAppLoc/temp/&file..txt);
%let guard_syscc=&syscc;
%let syscc=0;
%mp_assert(
  iftrue=(&guard_ret=0),
  desc=Check the syscc guard returns 0 rather than aborting
)
%mp_assert(
  iftrue=(&guard_syscc=1012),
  desc=Check the syscc guard leaves syscc alone
)
