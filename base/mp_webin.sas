/**
  @file
  @brief Fix the `_WEBIN` variables provided to SAS web services
  @details When uploading files to SAS Stored Processes or Viya Jobs a number
  of global macro variables are automatically created - however there are some
  differences in behaviour both between SAS 9 and Viya, and also between a
  single file upload and a multi-file upload.

  This macro "straightens" up the global macro variables to make it easier /
  simpler to write code that works in both environments and with a variable
  number of file inputs.

  After running this macro, the following global variables will *always* exist:
  @li `_WEBIN_FILE_COUNT`
  @li `_WEBIN_FILENAME1`
  @li `_WEBIN_FILEREF1`
  @li `_WEBIN_NAME1`

  Usage:

      %mp_webin()

  This was created as a macro procedure (over a macro function) as it will also
  use the filename statement in Viya environments (where `_webin_fileuri` is
  provided).

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas

**/

%macro mp_webin();

/* prepare global variables */
%global _webin_file_count
  _webin_filename _webin_filename1
  _webin_fileref _webin_fileref1
  _webin_fileuri _webin_fileuri1
  _webin_name _webin_name1
  ;

/* create initial versions */
%let _webin_file_count=%eval(&_webin_file_count+0);
%let _webin_filename1=%sysfunc(coalescec(&_webin_filename1,&_webin_filename));
%let _webin_fileref1=%sysfunc(coalescec(&_webin_fileref1,&_webin_fileref));
%let _webin_fileuri1=%sysfunc(coalescec(&_webin_fileuri1,&_webin_fileuri));
%let _webin_name1=%sysfunc(coalescec(&_webin_name1,&_webin_name));


/* If Viya, create temporary fileref(s) */
%local i;
%if %mf_getplatform()=SASVIYA %then %do i=1 %to &_webin_file_count;
  %let _webin_fileref&i=%mf_getuniquefileref();
  filename &&_webin_fileref&i filesrvc "&&_webin_fileuri&i";
%end;


%mend mp_webin;