/**
  @file
  @brief Create a Document object in a metadata folder
  @details Document objects are useful for storing properties in metadata.
    This macro is idempotent - it will not create an object with the same name
    in the same location, twice.
    Note - the filerefs are left open, to enable inspection after running the
    macro (or importing into an xmlmap if needed).

  usage:

      %mm_createdocument(tree=/User Folders/sasdemo
        ,name=MyNote)

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_verifymacvars.sas


  @param tree= The metadata folder uri, or the metadata path, in which to
    create the document.  This must exist.
  @param name= Document object name.  Avoid spaces.

  @param desc= Document description (optional)
  @param textrole= TextRole property (optional)
  @param frefin= fileref to use (enables change if there is a conflict)
  @param frefout= fileref to use (enables change if there is a conflict)
  @param mDebug= set to 1 to show debug messages in the log

  @author Allan Bowe

**/

%macro mm_createdocument(
    tree=/User Folders/sasdemo
    ,name=myNote
    ,desc=Created by &sysmacroname
    ,textrole=
    ,frefin=mm_in
    ,frefout=mm_out
    ,mDebug=1
    );

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

%mf_verifymacvars(tree name)

/**
  * check tree exists
  */

data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('type',type,'l');
  call symputx('treeuri',uri,'l');
run;

%mp_abort(
  iftrue= (&type ne Tree)
  ,mac=mm_createdocument.sas
  ,msg=Tree &tree does not exist!
)

/**
  * Check object does not exist already
  */
data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree/&name","Note",type,uri);
  call symputx('type',type,'l');
  call symputx('docuri',uri,'l');
  putlog (_all_)(=);
run;

%if &type = Document %then %do;
  %put Document &name already exists in &tree!;
  %return;
%end;

/**
  * Now we can create the document
  */
filename &frefin temp;

/* write header XML */
data _null_;
  file &frefin;
  name=quote("&name");
  desc=quote("&desc");
  textrole=quote("&textrole");
  treeuri=quote("&treeuri");

  put "<AddMetadata><Reposid>$METAREPOSITORY</Reposid>"/
    '<Metadata><Document IsHidden="0" PublicType="Note" UsageVersion="1000000"'/
    "  Name=" name " desc=" desc " TextRole=" textrole ">"/
    "<Notes> "/
    '  <TextStore IsHidden="0"  Name=' name ' UsageVersion="0" '/
    '    TextRole="SourceCode" StoredText="hello world" />' /
    '</Notes>'/
    /*URI="Document for public note" */
    "<Trees><Tree ObjRef=" treeuri "/></Trees>"/
    "</Document></Metadata><NS>SAS</NS>"/
    "<Flags>268435456</Flags></AddMetadata>";
run;

filename &frefout temp;

proc metadata in= &frefin out=&frefout verbose;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=1048576;
    input;
    put _infile_;
  run;
%end;

%mend;