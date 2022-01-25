/**
  @file
  @brief Returns the size of a file in bytes.
  @details Provide full path/filename.extension to the file, eg:

      %put %mf_getfilesize(fpath=C:\temp\myfile.txt);

  or, provide a libds value as follows:

      data x;do x=1 to 100000;y=x;output;end;run;
      %put %mf_getfilesize(libds=work.x,format=yes);

  Which gives:

  > 2mb

  @param [in] fpath= Full path and filename.  Provide this OR the libds value.
  @param [in] libds= (0) Library.dataset value (assumes library is BASE engine)
  @param [in] format= (NO) Set to yes to apply sizekmg. format

  @returns bytes

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getfilesize(fpath=,libds=0,format=NO
)/*/STORE SOURCE*/;

  %local rc fid fref bytes dsid lib vnum;

  %if &libds ne 0 %then %do;
    %let libds=%upcase(&libds);
    %if %index(&libds,.)=0 %then %let lib=WORK;
    %else %let lib=%scan(&libds,1,.);
    %let dsid=%sysfunc(open(
      sashelp.vtable(where=(libname="&lib" and memname="%scan(&libds,-1,.)")
        keep=libname memname filesize
      )
    ));
    %if (&dsid ^= 0) %then %do;
      %let vnum=%sysfunc(varnum(&dsid,FILESIZE));
      %let rc=%sysfunc(fetch(&dsid));
      %let bytes=%sysfunc(getvarn(&dsid,&vnum));
      %let rc= %sysfunc(close(&dsid));
    %end;
    %else %put &sysmacroname: &libds could not be opened! %sysfunc(sysmsg());
  %end;
  %else %do;
    %let rc=%sysfunc(filename(fref,&fpath));
    %let fid=%sysfunc(fopen(&fref));
    %let bytes=%sysfunc(finfo(&fid,File Size (bytes)));
    %let rc=%sysfunc(fclose(&fid));
    %let rc=%sysfunc(filename(fref));
  %end;

  %if &format=NO %then %do;
    &bytes
  %end;
  %else %do;
    %sysfunc(INPUTN(&bytes, best.),sizekmg.)
  %end;

%mend mf_getfilesize ;