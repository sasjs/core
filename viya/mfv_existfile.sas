/**
  @file
  @brief Checks whether a file exists in SAS Drive
  @details Returns 1 if the file exists, and 0 if it doesn't.  Works by
  attempting to assign a fileref with the filesrvc engine.  If not found, the
  syscc is automatically set to a non zero value - so in this case it is reset.
  To avoid hiding issues, there is therefore a test at the start to ensure the
  syscc is zero.

  Usage:

      %put %mfv_existfile(/does/exist.txt);
      %put %mfv_existfile(/does/not/exist.txt);

  @param filepath The full path to the file on SAS drive (eg /Public/myfile.txt)

  <h4> SAS Macros </h4>
  @li mf_abort.sas
  @li mf_getuniquefileref.sas

  <h4> Related Macros </h4>
  @li mfv_existfolder.sas

  @version 3.5
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mfv_existfile(filepath
)/*/STORE SOURCE*/;

  %mf_abort(
    iftrue=(&syscc ne 0),
    msg=Cannot enter mfv_existfile.sas with syscc=&syscc
  )

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