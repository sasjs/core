/**
  @file
  @brief Recursively create a metadata folder
  @details This macro was inspired by Paul Homes who wrote an early
    version (mkdirmd.sas) in 2010. The original is described here:
    https://platformadmin.com/blogs/paul/2010/07/mkdirmd/

    The macro will NOT create a new ROOT folder - not
    because it can't, but more because that is generally not something
    your administrator would like you to do!

    The macro is idempotent - if you run it twice, it will only create a folder
    once.

  Usage:

      %mm_createfolder(path=/some/meta/folder)

  @param [in] path= Name of the folder to create.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages


  @version 9.4
  @author Allan Bowe

**/

%macro mm_createfolder(path=,mDebug=0);
%put &sysmacroname: execution started for &path;
%local dbg errorcheck;
%if &mDebug=0 %then %let dbg=*;

%local parentFolderObjId child errorcheck paths;
%let paths=0;
%let errorcheck=1;

%if &syscc ge 4 %then %do;
  %put SYSCC=&syscc - this macro requires a clean session;
  %return;
%end;

data _null_;
  length objId parentId objType parent child $200
    folderPath $1000;
  call missing (of _all_);
  folderPath = "%trim(&path)";

  * remove any trailing slash ;
  if ( substr(folderPath,length(folderPath),1) = '/' ) then
    folderPath=substr(folderPath,1,length(folderPath)-1);

  * name must not be blank;
  if ( folderPath = '' ) then do;
    put "%str(ERR)OR: &sysmacroname PATH parameter value must be non-blank";
  end;

  * must have a starting slash ;
  if ( substr(folderPath,1,1) ne '/' ) then do;
    put "%str(ERR)OR: &sysmacroname PATH param value must have starting slash";
    stop;
  end;

  * check if folder already exists ;
  rc=metadata_pathobj('',cats(folderPath,"(Folder)"),"",objType,objId);
  if rc ge 1 then do;
    put "NOTE: Folder " folderPath " already exists!";
    stop;
  end;

  * do not create a root (one level) folder ;
  if countc(folderPath,'/')=1 then do;
    put "%str(ERR)OR: &sysmacroname will not create a new ROOT folder";
    stop;
  end;

  * check that root folder exists ;
  root=cats('/',scan(folderpath,1,'/'),"(Folder)");
  if metadata_pathobj('',root,"",objType,parentId)<1 then do;
    put "%str(ERR)OR: " root " does not exist!";
    stop;
  end;

  * check that parent folder exists ;
  child=scan(folderPath,-1,'/');
  parent=substr(folderpath,1,length(folderpath)-length(child)-1);
  rc=metadata_pathobj('',cats(parent,"(Folder)"),"",objType,parentId);
  if rc<1 then do;
    putlog 'The following folders will be created:';
    /* folder does not exist - so start from top and work down */
    length newpath $1000;
    paths=0;
    do x=2 to countw(folderpath,'/');
      newpath='';
      do i=1 to x;
        newpath=cats(newpath,'/',scan(folderpath,i,'/'));
      end;
      rc=metadata_pathobj('',cats(newpath,"(Folder)"),"",objType,parentId);
      if rc<1 then do;
        paths+1;
        call symputx(cats('path',paths),newpath);
        putlog newpath;
      end;
      call symputx('paths',paths);
    end;
  end;
  else putlog "parent " parent " exists";

  call symputx('parentFolderObjId',parentId,'l');
  call symputx('child',child,'l');
  call symputx('errorcheck',0,'l');

  &dbg put (_all_)(=);
run;

%if &errorcheck=1 or &syscc ge 4 %then %return;

%if &paths>0 %then %do x=1 %to &paths;
  %put executing recursive call for &&path&x;
  %mm_createfolder(path=&&path&x)
%end;
%else %do;
  filename __newdir temp;
  options noquotelenmax;
  %local inmeta;
  %put creating: &path;
  %let inmeta=<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata>
    <Tree Name='&child' PublicType='Folder' TreeType='BIP Folder'
    UsageVersion='1000000'><ParentTree><Tree ObjRef='&parentFolderObjId'/>
    </ParentTree></Tree></Metadata><NS>SAS</NS><Flags>268435456</Flags>
    </AddMetadata>;

  proc metadata in="&inmeta" out=__newdir verbose;
  run ;

  /* check it was successful */
  data _null_;
    length objId parentId objType parent child $200 ;
    call missing (of _all_);
    rc=metadata_pathobj('',cats("&path","(Folder)"),"",objType,objId);
    if rc ge 1 then do;
      putlog "SUCCCESS!  &path created.";
    end;
    else do;
      putlog "%str(ERR)OR: unsuccessful attempt to create &path";
      call symputx('syscc',8);
    end;
  run;

  /* write the response to the log for debugging */
  %if &mDebug ne 0 %then %do;
    data _null_;
      infile __newdir lrecl=32767;
      input;
      put _infile_;
    run;
  %end;
  filename __newdir clear;
%end;

%put &sysmacroname: execution finished for &path;
%mend mm_createfolder;