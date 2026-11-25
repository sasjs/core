/**
  @file
  @brief Read-only regression tests for ms_getgroups

  <h4> SAS Macros </h4>
  @li ms_getgroups.sas
  @li mp_assertmodel.sas
  @li mp_assert.sas
  @li mf_getuser.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/

data work.groupmodel;
  length groupuri groupname groupdesc $256;
  stop;
run;

%mp_assertscope(SNAPSHOT)
%ms_getgroups(outds=work.allgroups,mdebug=&sasjs_mdebug)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB2_JADP1LEN MCLIB2_JADPNUM MCLIB2_JADVLEN MC2_JADP1LEN
    MC2_JADPNUM MC2_JADVLEN MC0_JADP1LEN MC0_JADP2LEN MC0_JADPNUM
    MC0_JADVLEN
  ,desc=All groups scope
  ,outds=work.test_results
)
%mp_assertmodel(work.allgroups,base=work.groupmodel,key=groupuri
  ,desc=All groups model and key,outds=work.test_results)
%mp_assertdsobs(work.allgroups,test=ATLEAST 1
  ,desc=All groups not empty,outds=work.test_results)

%mp_assertscope(SNAPSHOT)
%ms_getgroups(user=%mf_getuser(),outds=work.usergroups)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB2_JADP1LEN MCLIB2_JADPNUM MCLIB2_JADVLEN MC2_JADP1LEN
    MC2_JADPNUM MC2_JADVLEN MC0_JADP1LEN MC0_JADP2LEN MC0_JADPNUM
    MC0_JADVLEN
  ,desc=User groups scope,outds=work.test_results)
%mp_assertmodel(work.usergroups,base=work.groupmodel,key=groupuri
  ,desc=User groups model and key,outds=work.test_results)
%mp_assertdsobs(work.usergroups,test=ATLEAST 1
  ,desc=User groups not empty,outds=work.test_results)

%mp_assertscope(SNAPSHOT)
%ms_getgroups(uid=&_sasjs_userid,outds=work.uidgroups)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB2_JADP1LEN MCLIB2_JADPNUM MCLIB2_JADVLEN MC2_JADP1LEN
    MC2_JADPNUM MC2_JADVLEN MC0_JADP1LEN MC0_JADP2LEN MC0_JADPNUM
    MC0_JADVLEN
  ,desc=UID groups scope,outds=work.test_results)
%mp_assertmodel(work.uidgroups,base=work.groupmodel,key=groupuri
  ,desc=UID groups model and key,outds=work.test_results)
%mp_assertdsobs(work.uidgroups,test=ATLEAST 1
  ,desc=UID groups not empty,outds=work.test_results)

proc sql noprint;
  select count(*) into :mismatch_all trimmed
  from work.usergroups as u left join work.allgroups as a
    on u.groupuri=a.groupuri
  where missing(a.groupuri) or u.groupname ne a.groupname
    or u.groupdesc ne a.groupdesc;
  select count(*) into :mismatch_uid trimmed
  from work.usergroups as u full join work.uidgroups as g
    on u.groupuri=g.groupuri
  where missing(u.groupuri) or missing(g.groupuri)
    or u.groupname ne g.groupname or u.groupdesc ne g.groupdesc;
quit;
%mp_assert(iftrue=(&mismatch_all=0)
  ,desc=User groups values match all groups,outds=work.test_results)
%mp_assert(iftrue=(&mismatch_uid=0)
  ,desc=Username and UID groups agree,outds=work.test_results)

/* an unknown user is not a failure: the model is returned with zero rows,
  matching the Viya behaviour for an unknown user */
%mp_assertscope(SNAPSHOT)
%ms_getgroups(user=nosuchuser7394,outds=work.nogroups)
%mp_assertscope(COMPARE
  ,ignorelist=MCLIB2_JADP1LEN MCLIB2_JADPNUM MCLIB2_JADVLEN MC2_JADP1LEN
    MC2_JADPNUM MC2_JADVLEN MC0_JADP1LEN MC0_JADP2LEN MC0_JADPNUM
    MC0_JADVLEN
  ,desc=Unknown user scope,outds=work.test_results)
%mp_assertmodel(work.nogroups,base=work.groupmodel,key=groupuri
  ,desc=Unknown user model and key,outds=work.test_results)
%mp_assertdsobs(work.nogroups,test=EMPTY
  ,desc=Unknown user has no groups,outds=work.test_results)

/* Independently read the API to verify the uid mapping and every value. */
%let rawheader=%mf_getuniquefileref();
%let rawbody=%mf_getuniquefileref();
%let rawlib=%mf_getuniquelibref();
data _null_;
  file &rawheader lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  if _n_=1 then put 'accept: application/json';
  put _infile_;
run;
proc http method='GET' headerin=&rawheader out=&rawbody
  url="&_sasjs_apiserverurl/SASjsApi/group";
run;
%mp_assert(iftrue=(&SYS_PROCHTTP_STATUS_CODE=200)
  ,desc=Independent API status,outds=work.test_results)
libname &rawlib JSON fileref=&rawbody;
proc sql noprint;
  select count(*) into :mismatch_raw trimmed
  from &rawlib..root as r full join work.allgroups as g
    on r.uid=g.groupuri
  where missing(r.uid) or missing(g.groupuri) or r.name ne g.groupname
    or r.description ne g.groupdesc;
quit;
%mp_assert(iftrue=(&mismatch_raw=0)
  ,desc=All group values match API uid name and description
  ,outds=work.test_results)
libname &rawlib clear;
filename &rawheader clear;
filename &rawbody clear;

/* Change only the current SAS process environment for the desktop branch. */
%let saved_mode=%sysget(MODE);
options set=MODE 'desktop';
%mp_assertscope(SNAPSHOT)
%ms_getgroups(outds=work.desktopgroups)
%mp_assertscope(COMPARE
  ,desc=Desktop groups scope,outds=work.test_results)
options set=MODE "&saved_mode";
%mp_assertmodel(work.desktopgroups,base=work.groupmodel,key=groupuri
  ,desc=Desktop group model and key,outds=work.test_results)
%mp_assertdsobs(work.desktopgroups,test=EQUALS 1
  ,desc=Desktop returns one group,outds=work.test_results)
%let desktop_match=0;
data _null_;
  set work.desktopgroups;
  if groupuri='1' and groupname=symget('sysuserid') and
    groupdesc=cats(symget('sysuserid'),' (group - desktop mode)') then
    call symputx('desktop_match',1);
run;
%mp_assert(iftrue=(&desktop_match=1)
  ,desc=Desktop group values,outds=work.test_results)
