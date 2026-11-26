/**
  @file
  @brief Regression tests for ms_getgroups with isolated group fixtures
  @details Requires an admin session for a local SASjs Server user. Group
  creation, membership changes, and deletion are performed on that server.
  Cleanup is best effort; a lost creation response or terminated session can
  leave a fixture that must be removed manually.

  <h4> SAS Macros </h4>
  @li mddl_getgroups.sas
  @li ms_getgroups.sas
  @li ms_creategroup.sas
  @li ms_adduser2group.sas
  @li mf_getuniquename.sas
  @li mp_assertmodel.sas
  @li mp_assert.sas
  @li mf_getuser.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/

/* JSON engine globals depend on the libref allocated in this session. */
%macro group_scope_compare(desc=);
  %local json_globals;
  %let json_globals=;
  proc sql noprint;
    select distinct name into :json_globals separated by ' '
    from dictionary.macros
    where scope='GLOBAL' and prxmatch(
      '/^MC(\d{1,6}|LIB\d{1,3})_JAD(P\d+LEN|PNUM|VLEN)$/i',strip(name));
  quit;
  %mp_assertscope(COMPARE,ignorelist=&json_globals
    ,desc=&desc,outds=work.test_results)
%mend group_scope_compare;

%macro run_group_fixture_test();
%local fixture_name1 fixture_name2 fixture_desc1 fixture_desc2
  fixture_status1 fixture_status2 fixture_valid1 fixture_valid2 mismatch_all
  mismatch_uid mismatch_raw unknown_user all_fixture1 all_fixture2
  user_fixture1 user_fixture2 uid_fixture1 uid_fixture2 rawheader rawbody rawlib
  saved_mode desktop_match;
/* Names fit the Server's 16-character alphanumeric limit. */
%let fixture_name1=%substr(%mf_getuniquename(prefix=g),1,16);
%let fixture_name2=%substr(%mf_getuniquename(prefix=g),1,16);
%let fixture_desc1=Getgroups member fixture;
%let fixture_desc2=Getgroups nonmember fixture;
%let fixture_uid1=;
%let fixture_uid2=;

%ms_creategroup(&fixture_name1,desc=&fixture_desc1,outds=work.fixture1)
%let fixture_status1=&SYS_PROCHTTP_STATUS_CODE;
data _null_;
  set work.fixture1;
  call symputx('fixture_uid1',uid,'g');
run;
%let fixture_valid1=%sysfunc(prxmatch(
  %str(/^[0-9a-fA-F]{24}$/),%superq(fixture_uid1)));
%mp_assert(iftrue=(&fixture_status1=200 and &fixture_valid1=1)
  ,desc=Created member fixture with UID,outds=work.test_results)
%if &fixture_status1 ne 200 or &fixture_valid1 ne 1 %then %return;

%ms_creategroup(&fixture_name2,desc=&fixture_desc2,outds=work.fixture2)
%let fixture_status2=&SYS_PROCHTTP_STATUS_CODE;
data _null_;
  set work.fixture2;
  call symputx('fixture_uid2',uid,'g');
run;
%let fixture_valid2=%sysfunc(prxmatch(
  %str(/^[0-9a-fA-F]{24}$/),%superq(fixture_uid2)));
%mp_assert(iftrue=(&fixture_status2=200 and &fixture_valid2=1)
  ,desc=Created nonmember fixture with UID,outds=work.test_results)
%if &fixture_status2 ne 200 or &fixture_valid2 ne 1 %then %return;

%ms_adduser2group(uid=&_sasjs_userid,gid=&fixture_uid1,outds=work.members)
%mp_assert(iftrue=(&SYS_PROCHTTP_STATUS_CODE=200)
  ,desc=Added current local user to fixture,outds=work.test_results)
%if &SYS_PROCHTTP_STATUS_CODE ne 200 %then %return;

%mddl_getgroups(work.groupmodel)

%mp_assertscope(SNAPSHOT)
%ms_getgroups(outds=work.allgroups,mdebug=&sasjs_mdebug)
%group_scope_compare(desc=All groups scope)
%mp_assertmodel(work.allgroups,base=work.groupmodel,key=groupuri
  ,desc=All groups model and key,outds=work.test_results)
%mp_assertdsobs(work.allgroups,test=ATLEAST 1
  ,desc=All groups not empty,outds=work.test_results)

%mp_assertscope(SNAPSHOT)
%ms_getgroups(user=%mf_getuser(),outds=work.usergroups)
%group_scope_compare(desc=User groups scope)
%mp_assertmodel(work.usergroups,base=work.groupmodel,key=groupuri
  ,desc=User groups model and key,outds=work.test_results)

%mp_assertscope(SNAPSHOT)
%ms_getgroups(uid=&_sasjs_userid,outds=work.uidgroups)
%group_scope_compare(desc=UID groups scope)
%mp_assertmodel(work.uidgroups,base=work.groupmodel,key=groupuri
  ,desc=UID groups model and key,outds=work.test_results)

proc sql noprint;
  select count(*) into :mismatch_all trimmed
  from work.usergroups as u left join work.allgroups as a
    on u.groupuri=a.groupuri
  where u.groupuri in ("&fixture_uid1","&fixture_uid2")
    and (missing(a.groupuri) or u.groupname ne a.groupname
      or u.groupdesc ne a.groupdesc);
  select count(*) into :mismatch_uid trimmed
  from work.usergroups as u full join work.uidgroups as g
    on u.groupuri=g.groupuri
  where coalesce(u.groupuri,g.groupuri) in ("&fixture_uid1","&fixture_uid2")
    and (missing(u.groupuri) or missing(g.groupuri)
      or u.groupname ne g.groupname or u.groupdesc ne g.groupdesc);
quit;
%mp_assert(iftrue=(&mismatch_all=0)
  ,desc=User groups values match all groups,outds=work.test_results)
%mp_assert(iftrue=(&mismatch_uid=0)
  ,desc=Username and UID groups agree,outds=work.test_results)

/* Match the two fixture IDs and every value, not pre-existing memberships. */
proc sql noprint;
  select count(*) into :all_fixture1 trimmed from work.allgroups
    where groupuri="&fixture_uid1" and groupname="&fixture_name1"
      and groupdesc="&fixture_desc1";
  select count(*) into :all_fixture2 trimmed from work.allgroups
    where groupuri="&fixture_uid2" and groupname="&fixture_name2"
      and groupdesc="&fixture_desc2";
  select count(*) into :user_fixture1 trimmed from work.usergroups
    where groupuri="&fixture_uid1" and groupname="&fixture_name1"
      and groupdesc="&fixture_desc1";
  select count(*) into :user_fixture2 trimmed from work.usergroups
    where groupuri="&fixture_uid2";
  select count(*) into :uid_fixture1 trimmed from work.uidgroups
    where groupuri="&fixture_uid1" and groupname="&fixture_name1"
      and groupdesc="&fixture_desc1";
  select count(*) into :uid_fixture2 trimmed from work.uidgroups
    where groupuri="&fixture_uid2";
quit;
%mp_assert(iftrue=(&all_fixture1=1 and &all_fixture2=1)
  ,desc=All groups contain exact fixture values,outds=work.test_results)
%mp_assert(iftrue=(&user_fixture1=1)
  ,desc=Username groups contain exact member fixture,outds=work.test_results)
%mp_assert(iftrue=(&user_fixture2=0)
  ,desc=Username groups exclude nonmember fixture,outds=work.test_results)
%mp_assert(iftrue=(&uid_fixture1=1)
  ,desc=UID groups contain exact member fixture,outds=work.test_results)
%mp_assert(iftrue=(&uid_fixture2=0)
  ,desc=UID groups exclude nonmember fixture,outds=work.test_results)

/* an unknown user is not a failure: the model is returned with zero rows,
  matching the Viya behaviour for an unknown user */
%let unknown_user=%substr(%mf_getuniquename(prefix=u),1,16);
%mp_assertscope(SNAPSHOT)
%ms_getgroups(user=&unknown_user,outds=work.nogroups)
%group_scope_compare(desc=Unknown user scope)
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
  where coalesce(r.uid,g.groupuri) in ("&fixture_uid1","&fixture_uid2")
    and (missing(r.uid) or missing(g.groupuri) or r.name ne g.groupname
      or r.description ne g.groupdesc);
quit;
%mp_assert(iftrue=(&mismatch_raw=0)
  ,desc=Fixture values match API uid name and description
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
%mend run_group_fixture_test;

/* Keep captured UIDs after an abort in the included test body. */
%global fixture_uid1 fixture_uid2 _SYSINCLUDEFILEDEVICE;
%let fixture_uid1=;
%let fixture_uid2=;
%let saved_include_device=%superq(_SYSINCLUDEFILEDEVICE);
%let saved_syntaxcheck=%sysfunc(getoption(syntaxcheck,keyword));
%let saved_obs=%sysfunc(getoption(obs,keyword));
%let saved_replace=%sysfunc(getoption(replace,keyword));
%let saved_bomfile=%sysfunc(getoption(bomfile,keyword));
%let saved_fixture_mode=%sysget(MODE);
%let test_body=%mf_getuniquefileref();
%let cleanup_header=%mf_getuniquefileref();
%let cleanup_body=%mf_getuniquefileref();
data _null_;
  file &cleanup_header lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  if _n_=1 then put 'accept: application/json';
  put _infile_;
run;
data _null_;
  file &test_body;
  put '%run_group_fixture_test()';
run;
%let _SYSINCLUDEFILEDEVICE=TEMP;
%include &test_body;
%let _SYSINCLUDEFILEDEVICE=&saved_include_device;
options set=MODE "&saved_fixture_mode";

/* Preserve the test status while allowing both deletion attempts. */
%let test_syscc=&syscc;
%let cleanup_syscc=0;
options nosyntaxcheck obs=max replace;
%let syscc=0;
%macro cleanup_group_fixture(uid=,label=);
  %local valid delete_status verify_status;
  /* A failed HTTP step must not suppress the next independent cleanup. */
  %let cleanup_syscc=%sysfunc(max(&cleanup_syscc,&syscc));
  %let syscc=0;
  %let valid=%sysfunc(prxmatch(%str(/^[0-9a-fA-F]{24}$/),%superq(uid)));
  %if &valid=1 %then %do;
    %let SYS_PROCHTTP_STATUS_CODE=0;
    proc http method='DELETE' headerin=&cleanup_header out=&cleanup_body
      url="&_sasjs_apiserverurl/SASjsApi/group/&uid";
    run;
    %let delete_status=&SYS_PROCHTTP_STATUS_CODE;
    %let cleanup_syscc=%sysfunc(max(&cleanup_syscc,&syscc));
    %let syscc=0;
    %let SYS_PROCHTTP_STATUS_CODE=0;
    proc http method='GET' headerin=&cleanup_header out=&cleanup_body
      url="&_sasjs_apiserverurl/SASjsApi/group/&uid";
    run;
    %let verify_status=&SYS_PROCHTTP_STATUS_CODE;
    %let cleanup_syscc=%sysfunc(max(&cleanup_syscc,&syscc));
    %let syscc=0;
    %mp_assert(iftrue=(&delete_status=200 and &verify_status=404)
      ,desc=Deleted and verified &label fixture,outds=work.test_results)
  %end;
  %else %do;
    %mp_assert(iftrue=(0=1)
      ,desc=Could not safely clean &label fixture UID,outds=work.test_results)
  %end;
%mend cleanup_group_fixture;
%cleanup_group_fixture(uid=&fixture_uid1,label=member)
%cleanup_group_fixture(uid=&fixture_uid2,label=nonmember)
filename &test_body clear;
filename &cleanup_header clear;
filename &cleanup_body clear;
%let cleanup_syscc=%sysfunc(max(&cleanup_syscc,&syscc));
options &saved_syntaxcheck &saved_obs &saved_replace &saved_bomfile;
%let syscc=%sysfunc(max(&test_syscc,&cleanup_syscc,&syscc));
