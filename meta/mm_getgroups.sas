/**
  @file
  @brief Creates dataset with all groups or just those for a particular user
  @details Provide a metadata user to get groups for just that user, or leave
    blank to return all groups.
  Usage:

    - all groups
    %mm_getGroups()

    - all groups for a particular user
    %mm_getgroups(user=&sysuserid)

  @param user= the metadata user to return groups for.  Leave blank for all
    groups.
  @param outds= the dataset to create that contains the list of groups
  @param repo= the metadata repository that contains the user/group information
  @param mDebug= set to 1 to show debug messages in the log

  @returns outds  dataset containing all groups in a column named "metagroup"
   - groupuri
   - groupname
   - groupdesc

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getGroups(
     user=
    ,outds=work.mm_getGroups
    ,repo=foundation
    ,mDebug=0
)/*/STORE SOURCE*/;

%local mD oldrepo;
%let oldrepo=%sysfunc(getoption(metarepository));
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_getGroups.sas;
%&mD.put _local_;

/* on some sites, user / group info is in a different metadata repo to the default */
%if &oldrepo ne &repo %then %do;
  options metarepository=&repo;
%end;

%if %length(&user)=0 %then %do;
  data &outds (keep=groupuri groupname groupdesc);
    length groupuri groupname groupdesc group_or_role $256;
    call missing(of _all_);
    i+1;
    do while
    (metadata_getnobj("omsobj:IdentityGroup?@Id contains '.'",i,groupuri)>0);
      rc=metadata_getattr(groupuri, "Name", groupname);
      rc=metadata_getattr(groupuri, "Desc", groupdesc);
      rc=metadata_getattr(groupuri,"PublicType",group_or_role);
      if Group_or_Role = 'UserGroup' then output;
      i+1;
    end;
  run;
%end;
%else %do;
  data &outds (keep=groupuri groupname groupdesc);
    length uri groupuri groupname groupdesc group_or_role $256;
    call missing(of _all_);
    rc=metadata_getnobj("omsobj:Person?@Name='&user'",1,uri);
    if rc<=0 then do;
      putlog "%str(WARN)ING: rc=" rc "&user not found "
          ", or there was an issue reading the repository.";
      stop;
    end;
    a=1;
    grpassn=metadata_getnasn(uri,"IdentityGroups",a,groupuri);
    if grpassn in (-3,-4) then do;
      putlog "%str(WARN)ING: No metadata groups found for &user";
      output;
    end;
    else do while (grpassn > 0);
      rc=metadata_getattr(groupuri, "Name", groupname);
      rc=metadata_getattr(groupuri, "Desc", groupdesc);
      a+1;
      rc=metadata_getattr(groupuri,"PublicType",group_or_role);
      if Group_or_Role = 'UserGroup' then output;
      grpassn=metadata_getnasn(uri,"IdentityGroups",a,groupuri);
    end;
  run;
%end;

%if &oldrepo ne &repo %then %do;
  options metarepository=&oldrepo;
%end;

%mend;