/**
  @file
  @brief Deletes a library by Name

  @details  Used to delete a library.
  Usage:

      %* create a library in the home directory ;
      %mm_createlibrary(
        libname=My Temp Library,
        libref=XXTEMPXX,
        tree=/User Folders/&sysuserid,
        directory=%sysfunc(pathname(work))
      )

      %* delete the library ;
      %mm_deletelibrary(name=My Temp Library)

  After running the above, the following will be shown in the log:

  ![](https://i.imgur.com/Y4Tog24.png)

  @param [in] name= () the name (not libref) of the library to be deleted

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mp_abort.sas


  @version 9.4
  @author Allan Bowe

**/

%macro mm_deletelibrary(
      name=
)/*/STORE SOURCE*/;


/**
  * Check if library exists and get uri
  */
data _null_;
  length type uri $256;
  rc=metadata_resolve("omsobj:SASLibrary?@Name='&name'",type,uri);
  call symputx('checktype',type,'l');
  call symputx('liburi',uri,'l');
  putlog (_all_)(=);
run;
%if &checktype ne SASLibrary %then %do;
  %put &sysmacroname: Library (&name) was not found, and so will not be deleted;
  %return;
%end;

%local fname1 fname2;
%let fname1=%mf_getuniquefileref();
%let fname2=%mf_getuniquefileref();

filename &fname1 temp lrecl=10000;
filename &fname2 temp lrecl=10000;
data _null_ ;
  file &fname1 ;
  put "<DeleteMetadata><Metadata><SASLibrary Id='&liburi'/>";
  put "</Metadata><NS>SAS</NS><Flags>268436480</Flags><Options/>";
  put "</DeleteMetadata>";
run ;
proc metadata in=&fname1 out=&fname2 verbose;run;

/* list the result */
data _null_;infile &fname2; input; list; run;

filename &fname1 clear;
filename &fname2 clear;

/**
  * Check deletion
  */
%local isgone;
data _null_;
  length type uri $256;
  call missing (of _all_);
  rc=metadata_resolve("omsobj:SASLibrary?@Id='&liburi'",type,uri);
  call symputx('isgone',type,'l');
run;

%mp_abort(iftrue=(&isgone = SASLibrary)
  ,mac=&sysmacroname
  ,msg=%str(Library (&name) NOT deleted)
)

%put &sysmacroname: Library &name (&liburi) was successfully deleted;

%mend mm_deletelibrary;
