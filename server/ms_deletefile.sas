/**
  @file
  @brief Deletes a file from SASjs Drive
  @details Deletes a file from SASjs Drive, if it exists.

  Example:

      filename stpcode temp;
      data _null_;
        file stpcode;
        put '%put hello world;';
      run;
      %ms_createfile(/some/stored/program.sas, inref=stpcode)

      %ms_deletefile(/some/stored/program.sas)

  @param [in] driveloc The full path to the file in SASjs Drive
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages


**/

%macro ms_deletefile(driveloc
    ,mdebug=0
  );

proc http method='DELETE'
  url="&_sasjs_apiserverurl/SASjsApi/drive/file?_filePath=&driveloc";
%if &mdebug=1 %then %do;
  debug level=2;
%end;
run;


%mend ms_deletefile;
