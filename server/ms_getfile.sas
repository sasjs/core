/**
  @file
  @brief Gets a file from SASjs Drive
  @details Fetches a file on SASjs Drive and stores it in the output fileref.

  Example:

      %ms_getfile(/some/stored/file.ext, outref=myfile)

  @param [in] driveloc The full path to the file in SASjs Drive
  @param [out] outref= (msgetfil) The fileref to contain the file.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages


**/

%macro ms_getfile(driveloc
    ,outref=msgetfil
    ,mdebug=0
  );

filename &outref temp;

proc http method='GET' out=&outref
  url="&_sasjs_apiserverurl/SASjsApi/drive/file?filePath=&driveloc";
%if &mdebug=1 %then %do;
  debug level=2;
%end;
run;


%mend ms_getfile;
