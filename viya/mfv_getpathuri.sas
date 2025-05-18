/**
  @file
  @brief Returns the uri of a file or folder
  @details The automatic variable _FILESRVC_[fref]_URI is used after assigning
  a fileref using the filesrvc engine.

  Usage:

      %put %mfv_existfile(/Public/folder/file.txt);
      %put %mfv_existfile(/Public/folder);

  @param [in] filepath The full path to the file on SAS drive
    (eg /Public/myfile.txt)

  <h4> SAS Macros </h4>
  @li mf_abort.sas
  @li mf_getuniquefileref.sas

  <h4> Related Macros </h4>
  @li mfv_existfile.sas
  @li mfv_existfolder.sas

  @version 3.5
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mfv_getpathuri(filepath
)/*/STORE SOURCE*/;

  %mf_abort(
    iftrue=(&syscc ne 0),
    msg=Cannot enter &sysmacroname with syscc=&syscc
  )

  %local fref rc path name;
  %let fref=%mf_getuniquefileref();
  %let name=%scan(&filepath,-1,/);
  %let path=%substr(&filepath,1,%length(&filepath)-%length(&name)-1);

  %if %sysfunc(filename(fref,,filesrvc,folderPath="&path" filename="&name"))=0
  %then %do;&&_FILESRVC_&fref._URI%let rc=%sysfunc(filename(fref));
  %end;
  %else %do;
    %put &sysmacroname: did not find &filepath;
    %let syscc=0;
  %end;

%mend mfv_getpathuri;