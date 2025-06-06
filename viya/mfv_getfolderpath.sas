/**
  @file
  @brief Returns the path of a folder from the URI
  @details Makes use of the SYSMSG() ER8OR response, which resolves the uri,
  seemingly without entering an er8or state.

  Usage:

      %mv_createfolder(path=/public/demo)
      %let uri=%mfv_getpathuri(/public/demo);
      %put %mfv_getfolderpath(&uri);

  Notice above the new path has an uppercase P - the correct path.

  @param [in] uri The uri of the folder -eg /folders/folders/xxxx)

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

  <h4> Related Macros </h4>
  @li mfv_getpathuri.sas

  @version 4
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/
%macro mfv_getfolderpath(uri
)/*/STORE SOURCE*/;

  %local fref rc path msg var /* var used to avoid delete timing issue */;
  %let fref=%mf_getuniquefileref();
  %if %quote(%substr(%str(&uri),1,17)) ne %quote(/folders/folders/)
  %then %do;
    %put &sysmacroname: Invalid URI: &uri;
  %end;
  %else %if %sysfunc(filename(fref,,filesrvc,folderuri="&uri" ))=0
  %then %do;
    %let var=_FILESRVC_&fref._URI;
    %local fid ;
    %let fid= %sysfunc(fopen(&fref,I));
    %let msg=%quote(%sysfunc(sysmsg()));

    %unquote(%scan(&msg,2,%str(,.)))

    %let rc=%sysfunc(fclose(&fid));
    %let rc=%sysfunc(filename(fref));
    %symdel &var;
  %end;
  %else %do;
    %put &sysmacroname: Not Found: &uri;
    %let syscc=0;
  %end;

%mend mfv_getfolderpath ;