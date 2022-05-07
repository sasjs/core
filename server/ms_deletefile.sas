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

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

**/

%macro ms_deletefile(driveloc
    ,mdebug=0
  );

%local headref;
%let headref=%mf_getuniquefileref();

data _null_;
  file &headref lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  put _infile_;
run;

proc http method='DELETE' headerin=&headref
  url="&_sasjs_apiserverurl/SASjsApi/drive/file?_filePath=&driveloc";
%if &mdebug=1 %then %do;
  debug level=2;
%end;
run;

filename &headref clear;

%mend ms_deletefile;
