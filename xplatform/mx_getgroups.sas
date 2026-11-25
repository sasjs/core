/**
  @file
  @brief Fetches groups on SAS 9, Viya or SASjs Server
  @details Returns the same three-column model on each platform. GROUPURI is
  the native group identifier, GROUPNAME the group name and GROUPDESC the
  description. Viya user memberships do not supply a description, so GROUPDESC
  is blank for those rows. Character lengths are 256 bytes.

  @param [in] mdebug= (0) Enable debug messages where supported
  @param [in] user= (0) Username to filter on, or 0 for all groups
  @param [in] uid= (0) SASjs Server user identifier to filter on
  @param [in] repo= (foundation) SAS 9 metadata repository
  @param [in] access_token_var= (ACCESS_TOKEN) Viya access token variable
  @param [in] grant_type= (sas_services) Viya authentication grant
  @param [out] outds= (work.mx_getgroups) Output groups dataset with character
    GROUPURI, GROUPNAME and GROUPDESC, each length 256 bytes

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mm_getgroups.sas
  @li mp_abort.sas
  @li ms_getgroups.sas
  @li mv_getgroups.sas
  @li mv_getusergroups.sas

**/

%macro mx_getgroups(
  mdebug=0,
  user=0,
  uid=0,
  repo=foundation,
  access_token_var=ACCESS_TOKEN,
  grant_type=sas_services,
  outds=work.mx_getgroups
);
%local platform libref1 mx_overlong;
%let platform=%mf_getplatform();

%if &platform=SASJS %then %do;
  %ms_getgroups(user=&user,uid=&uid,outds=&outds,mdebug=&mdebug)
%end;
%else %if &platform=SAS9 or &platform=SASMETA %then %do;
  %if &user=0 %then %let user=;
  %mm_getgroups(user=&user,outds=&outds,repo=&repo,mDebug=&mdebug)
%end;
%else %if &platform=SASVIYA %then %do;
  %if &user=0 %then %do;
    %mv_getgroups(access_token_var=&access_token_var,
      grant_type=&grant_type,outds=&outds)
  %end;
  %else %do;
    %mv_getusergroups(&user,outds=&outds,
      access_token_var=&access_token_var,grant_type=&grant_type)
    %let mx_overlong=0;
    data _null_;
      set &outds;
      if lengthn(id)>256 or lengthn(name)>256 then
        call symputx('mx_overlong',1,'L');
    run;
    %mp_abort(iftrue=(&mx_overlong=1),mac=mx_getgroups.sas,
      msg=%str(Viya group identifier or name exceeds 256 bytes))
    data &outds;
      length groupuri groupname groupdesc $256;
      set &outds;
      groupuri=id;
      groupname=name;
      call missing(groupdesc);
      keep groupuri groupname groupdesc;
    run;
  %end;
%end;
%else %do;
  %mp_abort(iftrue=(1=1),mac=mx_getgroups.sas,
    msg=%str(Unsupported SAS platform &platform))
%end;
proc sort data=&outds;
  by groupname;
run;
%mend mx_getgroups;
