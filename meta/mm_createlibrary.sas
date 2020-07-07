/**
  @file
  @brief Create a SAS Library
  @details Currently only supports BASE engine

    This macro is idempotent - if you run it twice (for the same libref or
    libname), it will only create one library.  There is a dependency on other
    macros in this library - they should be installed as a suite (see README).

  Usage:

    %mm_createlibrary(
       libname=My New Library
      ,libref=mynewlib
      ,libdesc=Super & <fine>
      ,engine=BASE
      ,tree=/User Folders/sasdemo
      ,servercontext=SASApp
      ,directory=/tmp/tests
      ,mDebug=1)

  <h4> Dependencies </h4>
  @li mf_verifymacvars.sas
  @li mm_createfolder.sas


  @param libname= Library name (as displayed to user, 256 chars). Duplicates
    are not created (case sensitive).
  @param libref= Library libref (8 chars).  Duplicate librefs are not created,
    HOWEVER- the check is not case sensitive - if *libref* exists, *LIBREF*
    will still be created.   Librefs created will always be uppercased.
  @param engine= Library engine (currently only BASE supported)
  @param tree= The metadata folder uri, or the metadata path, in which to
    create the library.
  @param servercontext= The SAS server against which the library is registered.
  @param IsPreassigned= set to 1 if the library should be pre-assigned.

  @param libdesc= Library description (optional)
  @param directory= Required for the BASE engine. The metadata directory objects
    are searched to find an existing one with a matching physical path.
    If more than one uri found with that path, then the first one will be used.
    If no URI is found, a new directory object will be created.  The physical
    path will also be created, if it doesn't exist.


  @param mDebug= set to 1 to show debug messages in the log
  @param frefin= fileref to use (enables change if there is a conflict).  The
    filerefs are left open, to enable inspection after running the
    macro (or importing into an xmlmap if needed).
  @param frefout= fileref to use (enables change if there is a conflict)


  @version 9.3
  @author Allan Bowe

**/

%macro mm_createlibrary(
     libname=My New Library
    ,libref=mynewlib
    ,libdesc=Created automatically using the mm_createlibrary macro
    ,engine=BASE
    ,tree=/User Folders/sasdemo
    ,servercontext=SASApp
    ,directory=/tmp/somelib
    ,IsPreassigned=0
    ,mDebug=0
    ,frefin=mm_in
    ,frefout=mm_out
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

%let libref=%upcase(&libref);

/**
 * Check Library does not exist already with this libname
 */
data _null_;
  length type uri $256;
  rc=metadata_resolve("omsobj:SASLibrary?@Name='&libname'",type,uri);
  call symputx('checktype',type,'l');
  call symputx('liburi',uri,'l');
  putlog (_all_)(=);
run;
%if &checktype = SASLibrary %then %do;
  %put WARNING: Library (&liburi) already exists with libname (&libname)  ;
  %return;
%end;

/**
 * Check Library does not exist already with this libref
 */
data _null_;
  length type uri $256;
  rc=metadata_resolve("omsobj:SASLibrary?@Libref='&libref'",type,uri);
  call symputx('checktype',type,'l');
  call symputx('liburi',uri,'l');
  putlog (_all_)(=);
run;
%if &checktype = SASLibrary %then %do;
  %put WARNING: Library (&liburi) already exists with libref (&libref)  ;
  %return;
%end;


/**
 * Attempt to create tree
 */
%mm_createfolder(path=&tree)

/**
 * check tree exists
 */
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('foldertype',type,'l');
  call symputx('treeuri',uri,'l');
run;
%if &foldertype ne Tree %then %do;
  %put WARNING: Tree &tree does not exist!;
  %return;
%end;

/**
 * Create filerefs for proc metadata call
 */
filename &frefin temp;
filename &frefout temp;

%if &engine=BASE %then %do;

  %mf_verifymacvars(libname libref engine servercontext tree)



  /**
   * Check that the ServerContext exists
   */
  data _null_;
    length type uri $256;
    rc=metadata_resolve("omsobj:ServerContext?@Name='&ServerContext'",type,uri);
    call symputx('checktype',type,'l');
    call symputx('serveruri',uri,'l');
    putlog (_all_)(=);
  run;
  %if &checktype ne ServerContext %then %do;
    %put %str(ERR)OR: ServerContext (&ServerContext) does not exist!;
    %return;
  %end;

  /**
   * Get prototype info
   */
  data _null_;
    length type uri str $256;
    str="omsobj:Prototype?@Name='Library.SAS.Prototype.Name.xmlKey.txt'";
    rc=metadata_resolve(str,type,uri);
    call symputx('checktype',type,'l');
    call symputx('prototypeuri',uri,'l');
    putlog (_all_)(=);
  run;
  %if &checktype ne Prototype %then %do;
    %put %str(ERR)OR: Prototype (Library.SAS.Prototype.Name.xmlKey.txt) not found!;
    %return;
  %end;

  /**
   * Check that Physical location exists
   */
  %if %sysfunc(fileexist(&directory))=0 %then %do;
    %put %str(ERR)OR: Physical directory (&directory) does not appear to exist!;
    %return;
  %end;

  /**
   * Check that Directory Object exists in metadata
   */
  data _null_;
    length type uri $256;
    rc=metadata_resolve("omsobj:Directory?@DirectoryRole='LibraryPath'"
      !!" and @DirectoryName='&directory'",type,uri);
    call symputx('checktype',type,'l');
    call symputx('directoryuri',uri,'l');
    putlog (_all_)(=);
  run;
  %if &checktype ne Directory %then %do;
    %put NOTE: Directory object does not exist for (&directory) location;
    %put NOTE: It will now be created;

    data _null_;
      file &frefin;
      directory=quote(symget('directory'));
      put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata> "/
      '<Directory UsageVersion="1000000" IsHidden="0" IsRelative="0"'/
      '  DirectoryRole="LibraryPath" Name="Path" DirectoryName=' directory '/>'/
      "</Metadata><NS>SAS</NS>"/
      "<Flags>268435456</Flags></AddMetadata>";
    run;

    proc metadata in= &frefin out=&frefout %if &mdebug=1 %then verbose;;
    run;
    %if &mdebug=1 %then %do;
      data _null_;
        infile &frefout lrecl=1048576;
        input; put _infile_;
      run;
    %end;
    %put NOTE: Checking to ensure directory (&directory) object was created;
    data _null_;
      length type uri $256;
      rc=metadata_resolve("omsobj:Directory?@DirectoryRole='LibraryPath'"
        !!" and @DirectoryName='&directory'",type,uri);
      call symputx('checktype2',type,'l');
      call symputx('directoryuri',uri,'l');
      %if &mdebug=1 %then putlog (_all_)(=);;
    run;
    %if &checktype2 ne Directory %then %do;
      %put %str(ERR)OR: Directory (&directory) object was NOT created!;
      %return;
    %end;
    %else %put NOTE: Directory (&directoryuri) successfully created!;
  %end;

  /**
   *  check SAS version
   */
  %if %sysevalf(&sysver lt 9.3) %then %do;
    %put WARNING: Version 9.3 or later required;
    %return;
  %end;

  /**
   * Prepare the XML and create the library
   */
  data _null_;
    file &frefin;
    treeuri=quote(symget('treeuri'));
    serveruri=quote(symget('serveruri'));
    directoryuri=quote(symget('directoryuri'));
    libname=quote(symget('libname'));
    libref=quote(symget('libref'));
    IsPreassigned=quote(symget('IsPreassigned'));
    prototypeuri=quote(symget('prototypeuri'));

    /* escape description so it can be stored as XML */
    libdesc=tranwrd(symget('libdesc'),'&','&amp;');
    libdesc=tranwrd(libdesc,'<','&lt;');
    libdesc=tranwrd(libdesc,'>','&gt;');
    libdesc=tranwrd(libdesc,"'",'&apos;');
    libdesc=tranwrd(libdesc,'"','&quot;');
    libdesc=tranwrd(libdesc,'0A'x,'&#10;');
    libdesc=tranwrd(libdesc,'0D'x,'&#13;');
    libdesc=tranwrd(libdesc,'$','&#36;');
    libdesc=quote(trim(libdesc));

    put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid><Metadata> "/
        '<SASLibrary Desc=' libdesc ' Engine="BASE" IsDBMSLibname="0" '/
        '  IsHidden="0" IsPreassigned=' IsPreassigned ' Libref=' libref /
        '  UsageVersion="1000000" PublicType="Library" name=' libname '>'/
        '  <DeployedComponents>'/
        '    <ServerContext ObjRef=' serveruri "/>"/
        '  </DeployedComponents>'/
        '  <PropertySets>'/
        '    <PropertySet Name="ModifiedByProductPropertySet" '/
        '      SetRole="ModifiedByProductPropertySet" UsageVersion="0" />'/
        '  </PropertySets>'/
        "  <Trees><Tree ObjRef=" treeuri "/></Trees>"/
        '  <UsingPackages> '/
        '    <Directory ObjRef=' directoryuri ' />'/
        '  </UsingPackages>'/
        '  <UsingPrototype>'/
        '    <Prototype ObjRef=' prototypeuri '/>'/
        '  </UsingPrototype>'/
        '</SASLibrary></Metadata><NS>SAS</NS>'/
        '<Flags>268435456</Flags></AddMetadata>';
  run;


  proc metadata in= &frefin out=&frefout %if &mdebug=1 %then verbose ;;
  run;

  %if &mdebug=1 %then %do;
    data _null_;
      infile &frefout lrecl=1048576;
      input;put _infile_;
    run;
  %end;
  %put NOTE: Checking to ensure library (&libname) was created;
  data _null_;
    length type uri $256;
    rc=metadata_pathobj("","&tree/&libname","Library",type,uri);
    call symputx('libtype',type,'l');
    call symputx('liburi',uri,'l');
    %if &mdebug=1 %then putlog (_all_)(=);;
  run;
  %if &libtype ne SASLibrary %then %do;
    %put %str(ERR)OR: Could not find (&libname) at (&tree)!!;
    %return;
  %end;
  %else %put NOTE: Library (&libname) successfully created in (&tree)!;
%end;
%else %do;
  %put %str(ERR)OR: Other library engine types are not yet supported!!;
%end;


/**
 * Wrap up
 */
%if &mdebug ne 1 %then %do;
  filename &frefin clear;
  filename &frefout clear;
%end;

%mend;
