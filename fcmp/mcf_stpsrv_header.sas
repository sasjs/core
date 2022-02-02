/**
  @file
  @brief Provides a replacement for the stpsrv_header function
  @details The stpsrv_header is normally a built-in function, used to set the
  headers for SAS 9 Stored Processes as documented here:
  https://go.documentation.sas.com/doc/en/itechcdc/9.4/stpug/srvhead.htm

  The purpose of this custom function is to provide a replacement when running
  similar code as a web service against
  [sasjs/server](https://github.com/sasjs/server).  It operates by creating a
  text file with the headers.  The location of this text file is determined by
  a macro variable (`sasjs_stpsrv_header_loc`) which needs to be injected into
  each service by the calling process, eg:

      %let sasjs_stpsrv_header_loc = C:/temp/some_uuid/stpsrv_header.txt;

  Note - the function works by appending headers to the file.  If multiple same-
  named headers are provided, they will all be appended - the calling process
  needs to pick up the last one.  This will mean removing the attribute if the
  final record has an empty value.

  The function takes the following (positional) parameters:

  | PARAMETER | DESCRIPTION |
  |------------|-------------|
  | name $  | name of the header attribute to create|
  | value  $  | value of the header attribute|

  It returns 0 if successful, or -1 if an error occured.

  Usage:

      %let sasjs_stpsrv_header_loc=%sysfunc(pathname(work))/stpsrv_header.txt;

      %mcf_stpsrv_header(wrap=YES, insert_cmplib=YES)

      data _null_;
        rc=stpsrv_header('Content-type','application/text');
        rc=stpsrv_header('Content-disposition',"attachment; filename=file.txt");
      run;

      data _null_;
        infile "&sasjs_stpsrv_header_loc";
        input;
        putlog _infile_;
      run;


  @param [out] wrap= (NO) Choose YES to add the proc fcmp wrapper.
  @param [out] lib= (work) The output library in which to create the catalog.
  @param [out] cat= (sasjs) The output catalog in which to create the package.
  @param [out] pkg= (utils) The output package in which to create the function.
    Uses a 3 part format:  libref.catalog.package
  @param [out] insert_cmplib= DEPRECATED - The CMPLIB option is checked and
    values inserted only if needed.

  <h4> SAS Macros </h4>
  @li mcf_init.sas

  <h4> Related Programs </h4>
  @li mcf_stpsrv_header.test.sas
  @li mp_init.sas

**/

%macro mcf_stpsrv_header(wrap=NO
  ,insert_cmplib=DEPRECATED
  ,lib=WORK
  ,cat=SASJS
  ,pkg=UTILS
)/*/STORE SOURCE*/;
%local i var cmpval found;
%if %mcf_init(stpsrv_header)=1 %then %return;

%if &wrap=YES  %then %do;
  proc fcmp outlib=&lib..&cat..&pkg;
%end;

function stpsrv_header(name $, value $);
  length loc $128 val $512;
  loc=symget('sasjs_stpsrv_header_loc');
  val=trim(name)!!': '!!value;
  length fref $8;
  rc=filename(fref,loc);
  if (rc ne 0) then return( -1 );
  fid = fopen(fref,'a');
  if (fid = 0) then return( -1 );
  rc=fput(fid, val);
  rc=fwrite(fid);
  rc=fclose(fid);
  rc=filename(fref);
  return(0);
endsub;

%if &wrap=YES %then %do;
  quit;
%end;

/* insert the CMPLIB if not already there */
%let cmpval=%sysfunc(getoption(cmplib));
%let found=0;
%do i=1 %to %sysfunc(countw(&cmpval,%str( %(%))));
  %let var=%scan(&cmpval,&i,%str( %(%)));
  %if &var=&lib..&cat %then %let found=1;
%end;
%if &found=0 %then %do;
  options insert=(CMPLIB=(&lib..&cat));
%end;

%mend mcf_stpsrv_header;