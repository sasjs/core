/**
  @file
  @brief Adds a user to a group
  @details Adds a user to a metadata group.  The macro first checks whether the
    user is in that group, and if not, the user is added.

  Usage:

    %mm_adduser2group(user=sasdemo
      ,group=someGroup)


  @param user= the user name (not displayname)
  @param group= the group to which to add the user

  @warning the macro does not check inherited group memberships - it looks at
    direct members only

  @version 9.3
  @author Allan Bowe

**/

%macro mm_adduser2group(user=
  ,group=
  ,mdebug=0
);
/* first, check if user is in group already exists */
%local check uuri guri;
%let check=ok;

data _null_;
  length uri type msg $256;
  call missing(of _all_);
  rc=metadata_getnobj("omsobj:Person?@Name='&user'",1,uri);
  if rc<=0 then do;
    msg="%str(WARN)ING: rc="!!cats(rc)!!" &user not found "!!
        ", or there was an err reading the repository.";
    call symputx('check',msg);
    putlog msg;
    stop;
  end;
  call symputx('uuri',scan(uri,2,'\'));

  rc=metadata_getnobj("omsobj:IdentityGroup?@Name='&group'",1,uri);
  if rc<=0 then do;
    msg="%str(WARN)ING: rc="!!cats(rc)!!" &group not found "!!
        ", or there was an err reading the repository.";
    call symputx('check',msg);
    putlog msg;
    stop;
  end;
  call symputx('guri',scan(uri,2,'\'));

  rc=metadata_getnobj("omsobj:Person?Person[@Name='&user'][IdentityGroups/*[@Name='&group']]",1,uri);
  if rc=0 then do;
    msg="%str(WARN)ING: rc="!!cats(rc)!!" &user already in &group";
    call symputx('check',msg);
    stop;
  end;

  if &mdebug ne 0 then put (_all_)(=);
run;

/* stop if issues */
%if %quote(&check) ne %quote(ok) %then %do;
  %put &check;
  %return;
%end;

%if %length(&syscc) ge 4 %then %do;
  %put WARNING:  SYSCC=&syscc, exiting &sysmacroname;
  %return;
%end;


filename __us2grp temp;

proc metadata in= "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>
    <Person Id='&uuri'><IdentityGroups><IdentityGroup ObjRef='&guri' />
    </IdentityGroups></Person></Metadata>
    <NS>SAS</NS><Flags>268435456</Flags></UpdateMetadata>"
  out=__us2grp verbose;
run;

%if &mdebug ne 0 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile __us2grp lrecl=32767;
    input;
    put _infile_;
  run;
%end;

filename __us2grp clear;

%mend;