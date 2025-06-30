/**
  @file
  @brief Checks whether a folder exists in SAS Drive
  @details Returns 1 if the folder exists, and 0 if it doesn't.  Works by
  attempting to assign a fileref with the filesrvc engine.  If not found, the
  syscc is automatically set to a non zero value - so in this case it is reset.
  To avoid hiding issues, there is therefore a test at the start to ensure the
  syscc is zero.

  Usage:

      %put %mfv_existfolder(/does/exist);
      %put %mfv_existfolder(/does/not/exist);

  @param [in] path The path to the folder on SAS drive

  <h4> SAS Macros </h4>
  @li mf_abort.sas
  @li mf_getuniquefileref.sas

  <h4> Related Macros </h4>
  @li mfv_existfile.sas

  @version 3.5
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mfv_existfolder(path
)/*/STORE SOURCE*/;

  %mf_abort(
    iftrue=(&syscc ne 0),
    msg=Cannot enter mfv_existfolder.sas with syscc=&syscc
  )

  %local fref rc var;
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

  %mf_abort(
    iftrue=(&syscc ne 0),
    msg=Cannot leave mfv_existfolder.sas with syscc=&syscc
  )

%mend mfv_existfolder;