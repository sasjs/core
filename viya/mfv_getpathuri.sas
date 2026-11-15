/**
  @file
  @brief Returns the uri of a file or folder
  @details The automatic variable `_FILESRVC_[fref]_URI` is used after assigning
  a fileref using the filesrvc engine.  If the path does not exist the macro
  prints a note, returns nothing, and resets syscc to zero.

  A non zero syscc on entry means an earlier step has already failed.  The macro
  logs a %str(ERR)OR: line and returns an empty uri without touching syscc, so a
  caller that tests the uri for blankness sees no path, and the failure stays
  visible in syscc.

  Usage:

      %put %mfv_getpathuri(/Public/folder/file.txt);
      %put %mfv_getpathuri(/Public/folder);

  @param [in] filepath The full path to the file on SAS drive
    (eg /Public/myfile.txt)

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

  <h4> Related Macros </h4>
  @li mfv_existfile.sas
  @li mfv_existfolder.sas

  @version 3.5
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mfv_getpathuri(filepath
)/*/STORE SOURCE*/;

  %local fref rc path name var /* var is used to avoid delete timing issue */;

  %if &syscc ne 0 %then %do;
    %put %str(ERR)OR: mfv_getpathuri.sas cannot execute with syscc=&syscc;
    %return;
  %end;

  %let fref=%mf_getuniquefileref();
  %let name=%scan(&filepath,-1,/);
  %let path=%substr(&filepath,1,%length(&filepath)-%length(&name)-1);

  %if %sysfunc(filename(fref,,filesrvc,folderPath="&path" filename="&name"))=0
  %then %do;
    %let var=_FILESRVC_&fref._URI;
    %str(&&&var)
    %let rc=%sysfunc(filename(fref));
    %symdel &var;
  %end;
  %else %do;
    %put &sysmacroname: did not find &filepath;
    %let syscc=0;
  %end;

%mend mfv_getpathuri;
