/**
  @file
  @brief Checks whether a file exists in SAS Drive
  @details Returns 1 if the file exists, and 0 if it doesn't.  Works by
  attempting to assign a fileref with the filesrvc engine.  When the file is
  not found the filename function sets syscc to a non zero value, so the macro
  resets syscc to zero and returns 0: the return value carries the answer, and
  a caller that needs syscc preserved across the call should save it first.

  Usage:

      %put %mfv_existfile(/does/exist.txt);
      %put %mfv_existfile(/does/not/exist.txt);

  @param [in] filepath The full path to the file on SAS drive
    (eg /Public/myfile.txt)

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

  <h4> Related Macros </h4>
  @li mfv_existfolder.sas

  @version 3.5
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mfv_existfile(filepath
)/*/STORE SOURCE*/;

  %local fref rc path name;
  %let fref=%mf_getuniquefileref();
  %let name=%scan(&filepath,-1,/);
  %let path=%substr(&filepath,1,%length(&filepath)-%length(&name)-1);

  %if %sysfunc(filename(fref,,filesrvc,folderPath="&path" filename="&name"))=0
  %then %do;
    %sysfunc(fexist(&fref))
    %let rc=%sysfunc(filename(fref));
  %end;
  %else %do;
    0
    %let syscc=0;
  %end;

%mend mfv_existfile;
