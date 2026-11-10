/**
  @file
  @brief Checks whether a folder exists in SAS Drive
  @details Returns 1 if the folder exists, and 0 if it doesn't.  Works by
  attempting to assign a fileref with the filesrvc engine.  When the folder is
  not found the filename function sets syscc to a non zero value, so the macro
  resets syscc to zero and returns 0.

  A non zero syscc on entry means an earlier step has already failed.
  Rather than report such a folder as missing, or end the step, the macro
  logs a %str(ERR)OR: line and returns without a value, leaving syscc
  as it was so the caller's failure stays visible.

  Usage:

      %put %mfv_existfolder(/does/exist);
      %put %mfv_existfolder(/does/not/exist);

  @param [in] path The path to the folder on SAS drive

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

  <h4> Related Macros </h4>
  @li mfv_existfile.sas

  @version 3.5
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mfv_existfolder(path
)/*/STORE SOURCE*/;

  %local fref rc var;

  %if &syscc ne 0 %then %do;
    %put %str(ERR)OR: mfv_existfolder.sas cannot execute with syscc=&syscc;
    %return;
  %end;

  %let fref=%mf_getuniquefileref();

  %if %sysfunc(filename(fref,,filesrvc,folderPath="&path"))=0 %then %do;
    1
    %let var=_FILESRVC_&fref._URI;
    %let rc=%sysfunc(filename(fref));
    %symdel &var;
  %end;
  %else %do;
    0
    %let syscc=0;
  %end;

%mend mfv_existfolder;
