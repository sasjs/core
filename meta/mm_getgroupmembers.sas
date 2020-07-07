/**
  @file
  @brief Creates dataset with all members of a metadata group
  @details
  
  usage:
  
    %mm_getgroupmembers(someGroupName
      ,outds=work.mm_getgroupmembers 
      ,emails=YES)

  @param group metadata group for which to bring back members
  @param outds= the dataset to create that contains the list of members
  @param emails= set to YES to bring back email addresses
  @param id= set to yes if passing an ID rather than a group name

  @returns outds  dataset containing all members of the metadata group

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getgroupmembers(
    group /* metadata group for which to bring back members */
    ,outds=work.mm_getgroupmembers /* output dataset to contain the results */
    ,emails=NO /* set to yes to bring back emails also */
    ,id=NO /* set to yes if passing an ID rather than group name */
)/*/STORE SOURCE*/;

  data &outds ;
    attrib uriGrp uriMem GroupId GroupName Group_or_Role MemberName MemberType
      euri email           length=$64
      GroupDesc            length=$256
      rcGrp rcMem rc i j   length=3;
    call missing (of _all_);
    drop uriGrp uriMem rcGrp rcMem rc i j arc ;

    i=1;
    * Grab the URI for the first Group ;
    %if &id=NO %then %do;
      rcGrp=metadata_getnobj("omsobj:IdentityGroup?@Name='&group'",i,uriGrp);
    %end;
    %else %do;
      rcGrp=metadata_getnobj("omsobj:IdentityGroup?@Id='&group'",i,uriGrp);
    %end;
    * If Group found, enter do loop ;
    if rcGrp>0 then do;
      call missing (rcMem,uriMem,GroupId,GroupName,Group_or_Role
        ,MemberName,MemberType);
      * get group info ;
      rc = metadata_getattr(uriGrp,"Id",GroupId);
      rc = metadata_getattr(uriGrp,"Name",GroupName);
      rc = metadata_getattr(uriGrp,"PublicType",Group_or_Role);
      rc = metadata_getattr(uriGrp,"Desc",GroupDesc);
      j=1;
      do while (metadata_getnasn(uriGrp,"MemberIdentities",j,uriMem) > 0);
        call missing (MemberName, MemberType, email);
        rc = metadata_getattr(uriMem,"Name",MemberName);
        rc = metadata_getattr(uriMem,"PublicType",MemberType);
        if membertype='User' and "&emails"='YES' then do;
          if metadata_getnasn(uriMem,"EmailAddresses",1,euri)>0 then do;
            arc=metadata_getattr(euri,"Address",email);
          end;
        end;
        output;
        j+1;
      end;
    end;
  run;

%mend;
