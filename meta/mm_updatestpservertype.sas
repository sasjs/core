/**
  @file mm_updatestpservertype.sas
  @brief Updates a type 2 stored process to run on STP or WKS context
  @details Only works on Type 2 (9.3 compatible) STPs

  Usage:

    %mm_updatestpservertype(target=/some/meta/path/myStoredProcess
      ,type=WKS)

  <h4> SAS Macros </h4>

  @param target= full path to the STP being deleted
  @param type= Either WKS or STP depending on whether Workspace or Stored Process
        type required

  @version 9.4
  @author Allan Bowe

**/

%macro mm_updatestpservertype(
  target=
  ,type=
)/*/STORE SOURCE*/;

/**
 * Check STP does exist
 */
%local cmtype;
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&target",'StoredProcess',type,uri);
  call symputx('cmtype',type,'l');
  call symputx('stpuri',uri,'l');
run;
%if &cmtype ne ClassifierMap %then %do;
  %put WARNING: No Stored Process found at &target;
  %return;
%end;

%local newtype;
%if &type=WKS %then %let newtype=Wks;
%else %let newtype=Sps;

%local result;
%let result=NOT FOUND;
data _null_;
  length uri name value $256;
  n=1;
  do while(metadata_getnasn("&stpuri","Notes",n,uri)>0);
    n+1;
    rc=metadata_getattr(uri,"Name",name);
    if name='Stored Process' then do;
      rc = METADATA_SETATTR(uri,'StoredText','<?xml version="1.0" encoding="UTF-8"?>'
        !!'<StoredProcess><ServerContext LogicalServerType="'!!"&newtype"
        !!'" OtherAllowed="false"/><ResultCapabilities Package="false" '
        !!' Streaming="true"/><OutputParameters/></StoredProcess>');
      if rc=0 then call symputx('result','SUCCESS');
      stop;
    end;
  end;
run;
%if &result=SUCCESS %then %put NOTE: SUCCESS: STP &target changed to &type type;
%else %put %str(ERR)OR: Issue with &sysmacroname;

%mend;
