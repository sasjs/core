/**
  @file
  @brief Gets a file from SASjs Drive
  @details Fetches a file on SASjs Drive and stores it in the output fileref.

  Example:

      %ms_getfile(/some/stored/file.ext, outref=myfile)

  @param [in] driveloc The full path to the file in SASjs Drive
  @param [out] outref= (msgetfil) The fileref to contain the file.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas

**/

%macro ms_getfile(driveloc
    ,outref=msgetfil
    ,mdebug=0
  );

/* use the recfm in a separate fileref to avoid issues with subsequent reads */
%local binaryfref floc;
%let binaryfref=%mf_getuniquefileref();
%let floc=%sysfunc(pathname(work))/%mf_getuniquename().txt;
filename &outref "&floc";
filename &binaryfref "&floc" recfm=n;

proc http method='GET' out=&binaryfref
  url="&_sasjs_apiserverurl/SASjsApi/drive/file?_filePath=&driveloc";
%if &mdebug=1 %then %do;
  debug level=2;
%end;
run;

filename &binaryfref clear;

%mend ms_getfile;
