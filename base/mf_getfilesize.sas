/**
  @file
  @brief Returns the size of a file in bytes.
  @details Provide full path/filename.extension to the file, eg:

      %put %mf_getfilesize(fpath=C:\temp\myfile.txt);

      or

      data x;do x=1 to 100000;y=x;output;end;run;
      %put %mf_getfilesize(libds=work.x,format=yes);

      gives:

      2mb

  @param fpath= full path and filename.  Provide this OR the libds value.
  @param libds= library.dataset value (assumes library is BASE engine)
  @param format=  set to yes to apply sizekmg. format
  @returns bytes

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getfilesize(fpath=,libds=0,format=NO
)/*/STORE SOURCE*/;

  %if &libds ne 0 %then %do;
    %let fpath=%sysfunc(pathname(%scan(&libds,1,.)))/%scan(&libds,2,.).sas7bdat;
  %end;

  %local rc fid fref bytes;
  %let rc=%sysfunc(filename(fref,&fpath));
  %let fid=%sysfunc(fopen(&fref));
  %let bytes=%sysfunc(finfo(&fid,File Size (bytes)));
  %let rc=%sysfunc(fclose(&fid));
  %let rc=%sysfunc(filename(fref));

  %if &format=NO %then %do;
     &bytes
  %end;
  %else %do;
    %sysfunc(INPUTN(&bytes, best.),sizekmg.)
  %end;

%mend ;