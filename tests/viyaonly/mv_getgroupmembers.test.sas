/**
  @file
  @brief Testing mv_getgroupmembers macro
  @details The populated and unknown-group paths have fixtures here. The third
    path - a 200 whose items dataset carries no member columns, which is what an
    empty group answers - has no fixture: an empty group is an estate fact
    (creating one is refused with 403), so that branch is proven on a live
    estate only, against a stock group that happens to have no members.

  <h4> SAS Macros </h4>
  @li mf_existvar.sas
  @li mf_getplatform.sas
  @li mf_getuser.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas
  @li mv_getgroupmembers.sas
  @li mv_getusergroups.sas

**/

/* Ignore only known JSON engine globals for the libref about to be used. */
%macro groupmember_scope_compare(desc=,json_libref=);
  %local json_globals;
  %let json_globals=;
  proc sql noprint;
    select distinct name into :json_globals separated by ' '
    from dictionary.macros
    where scope='GLOBAL'
      and upcase(scan(strip(name),1,'_'))=upcase(symget('json_libref'))
      and countw(strip(name),'_')=2
      and prxmatch('/^JAD(P\d+LEN|PNUM|VLEN)$/i',scan(strip(name),2,'_'));
  quit;
  %mp_assertscope(COMPARE,ignorelist=&json_globals
    ,desc=&desc,outds=work.test_results)
%mend groupmember_scope_compare;

/* The independent model covers the six documented member columns. */
data work.membermodel;
  length version 8 id $256 name $256 providerId $32 implicit 8 type $32;
  call missing(of _all_);
  stop;
run;

/* Compare only documented columns; leave the macro output unchanged. */
%macro groupmember_model_input(inds,outds);
  %local col i keepcols;
  %let keepcols=;
  %do i=1 %to 6;
    %let col=%scan(version id name providerId implicit type,&i);
    %if %mf_existvar(&inds,&col)>0 %then %let keepcols=&keepcols &col;
  %end;
  data &outds;
    set &inds;
    %if %length(%superq(keepcols))>0 %then %do;
      keep &keepcols;
    %end;
    %else %do;
      length _member_model_missing 8;
      _member_model_missing=1;
      keep _member_model_missing;
    %end;
  run;
%mend groupmember_model_input;

%macro test_groupmembers();
%local groupmember_libref groupid candidate i
  member_token member_probe_ref member_probe_status member_probe_failed
  member_probe_url;

/* An implicit or indirect group may have no listed members. */
%mv_getusergroups(user=%mf_getuser(), outds=work.mygroups,
  access_token_var=member_token)
%let groupid=;
%let member_probe_failed=0;
%do i=1 %to %mf_nobs(work.mygroups);
  %let candidate=;
  data _null_;
    member_row=&i;
    set work.mygroups point=member_row;
    /* Only URL path-safe, macro-literal characters; exclude dot segments. */
    if not missing(id) and id not in ('.','..') and
      verify(trim(id),
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~')=0
      then call symputx('candidate',id,'l');
    stop;
  run;
  %if %length(%superq(candidate))>0 %then %do;
    /* Check permission before calling the aborting macro. */
    %let member_probe_ref=%mf_getuniquefileref();
    %let member_probe_url=%mf_getplatform(VIYARESTAPI)/identities/groups;
    proc http method='GET' out=&member_probe_ref oauth_bearer=sas_services
      url="&member_probe_url/%superq(candidate)/members?limit=10000";
      headers "Accept"="application/json";
    run;
    %let member_probe_status=&SYS_PROCHTTP_STATUS_CODE;
    filename &member_probe_ref clear;
    %if &member_probe_status=200 %then %do;
      %mv_getgroupmembers(group=%superq(candidate),outds=work.member_fixture,
        access_token_var=member_token)
      %if %mf_nobs(work.member_fixture)>0 %then %do;
        %let groupid=%superq(candidate);
        %goto fixture_found;
      %end;
    %end;
    %else %if &member_probe_status ne 403 and
      &member_probe_status ne 404 %then %do;
      %put %str(ERR)OR: Fixture probe returned HTTP &member_probe_status.;
      %let member_probe_failed=1;
      %goto fixture_found;
    %end;
  %end;
%end;
%fixture_found:
%mp_assert(iftrue=(&member_probe_failed=0),
  desc=Membership fixture probes have no unexpected HTTP status,
  outds=work.test_results
)
%mp_assert(iftrue=(%length(%superq(groupid))>0),
  desc=A populated membership group with a safe fixture ID is available,
  outds=work.test_results
)
%if %length(%superq(groupid))=0 %then %do;
  data _null_;
    putlog 'ERR' 'OR: No populated group with a safe fixture ID found.';
    call symputx('syscc',max(input(symget('syscc'),best32.),1012),'g');
  run;
%end;
%else %do;

/* Predict the JSON libref after fixture selection has released it. */
%let groupmember_libref=%mf_getuniquelibref();
%mp_assertscope(SNAPSHOT)
%mv_getgroupmembers(group=%superq(groupid), outds=work.groupmembers,
  access_token_var=member_token)
%groupmember_scope_compare(desc=mv_getgroupmembers does not leak scope,
  json_libref=&groupmember_libref)
%mp_assert(iftrue=(&SYS_PROCHTTP_STATUS_CODE=200),
  desc=The populated group request returns HTTP 200,
  outds=work.test_results
)
/* A user and a group may share an ID, so the key includes identity type. */
%groupmember_model_input(work.groupmembers,work.members_model_input)
%mp_assertmodel(work.members_model_input,base=work.membermodel,key=id type,
  desc=Populated members match the model and have unique identity keys,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%sysfunc(exist(work.groupmembers))=1),
  desc=Check the group members dataset was created
)
%mp_assert(
  iftrue=(%mf_nobs(work.groupmembers)>0),
  desc=Check the group has at least one member
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,id)>0),
  desc=Check the dataset carries an id column
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,name)>0),
  desc=Check the dataset carries a name column
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,providerId)>0),
  desc=Check the dataset carries a providerId column
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,implicit)>0),
  desc=Check the dataset carries an implicit column
)
%mp_assert(
  iftrue=(%mf_existvar(work.groupmembers,type)>0),
  desc=Check the dataset carries a type column
)
%end;

/* a group id the server does not know - the macro answers with the documented
  columns and zero rows rather than one all-missing observation */
%mp_assertscope(SNAPSHOT)
%mv_getgroupmembers(group=no_such_group_sasjs_core, outds=work.unknown,
  access_token_var=member_token)
%mp_assertscope(COMPARE,
  desc=mv_getgroupmembers does not leak scope on an unknown group,
  outds=work.test_results)
%mp_assert(iftrue=(&SYS_PROCHTTP_STATUS_CODE=404),
  desc=The unknown group request returns HTTP 404,
  outds=work.test_results
)
%groupmember_model_input(work.unknown,work.unknown_model_input)
%mp_assertmodel(work.unknown_model_input,base=work.membermodel,
  desc=Unknown group members match the documented model,
  outds=work.test_results
)
%mp_assertdsobs(work.unknown,
  desc=Check an unknown group returns no rows,
  test=EMPTY,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_existvar(work.unknown,providerId)>0),
  desc=Check the unknown-group listing carries a providerId column
)
%mp_assert(
  iftrue=(%mf_existvar(work.unknown,type)>0),
  desc=Check the unknown-group listing carries a type column
)
%mend test_groupmembers;
%test_groupmembers()
