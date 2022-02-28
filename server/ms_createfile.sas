/**
  @file
  @brief Creates a file on SASjs Drive
  @details Creates a file on SASjs Drive. To use the file as a Stored Program,
  it must have a ".sas" extension.

  Example:

      filename stpcode temp;
      data _null_;
        file stpcode;
        put '%put hello world;';
      run;
      %ms_createfile(/some/stored/program.sas, inref=stpcode)

  @param [in] driveloc The full path to the file in SASjs Drive
  @param [in] inref= (0) The fileref containing the file to create.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mp_abort.sas

**/

%macro ms_createfile(driveloc
    ,inref=0
    ,mdebug=0
  );

%local fname0 fname1 boundary fname statcd msg;
%let fname0=%mf_getuniquefileref();
%let fname1=%mf_getuniquefileref();
%let boundary=%mf_getuniquename();

data _null_;
  file &fname0 termstr=crlf;
  infile &inref end=eof;
  if _n_ = 1 then do;
    put "--&boundary.";
    put 'Content-Disposition: form-data; name="filePath"';
    put ;
    put "&driveloc";
    put "--&boundary";
    put 'Content-Disposition: form-data; name="file"; filename="ignore.sas"';
    put "Content-Type: text/plain";
    put ;
  end;
  input;
  put _infile_; /* add the actual file to be sent */
  if eof then do;
    put ;
    put "--&boundary--";
  end;
run;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fname0;
    input;
    put _infile_;
  run;
%end;

proc http method='POST' in=&fname0 out=&fname1
  url="&_sasjs_apiserverurl/SASjsApi/drive/file";
  headers "Content-Type"="multipart/form-data; boundary=&boundary";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;

%let statcd=0;
data _null_;
  infile &fname1;
  input;
  putlog _infile_;
  if _infile_='{"status":"success"}' then call symputx('statcd',1,'l');
  else call symputx('msg',_infile_,'l');
run;

%mp_abort(
  iftrue=(&statcd=0)
  ,mac=ms_createfile.sas
  ,msg=%superq(msg)
)

%mend ms_createfile;
