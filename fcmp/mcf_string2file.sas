/**
  @file
  @brief Adds a string to a file
  @details Creates an fcmp function for appending a string to an external file.
  If the file does not exist, it is created.

  The function itself takes the following (positional) parameters:

  | PARAMETER | DESCRIPTION |
  |------------|-------------|
  | filepath $  | full path to the file|
  | string  $  | string to add to the file |
  | mode $     | mode of the output - either APPEND (default) or CREATE |

  It returns 0 if successful, or -1 if an error occured.

  Usage:

      %mcf_string2file(wrap=YES, insert_cmplib=YES)

      data _null_;
        rc=mcf_string2file(
          "%sysfunc(pathname(work))/newfile.txt"
          , "This is a test"
          , "CREATE");
      run;

      data _null_;
        infile "%sysfunc(pathname(work))/newfile.txt";
        input;
        putlog _infile_;
      run;

  @param [out] wrap= (NO) Choose YES to add the proc fcmp wrapper.
  @param [out] insert_cmplib= (NO) Choose YES to insert the package into the
    CMPLIB reference.
  @param [out] lib= (work) The output library in which to create the catalog.
  @param [out] cat= (sasjs) The output catalog in which to create the package.
  @param [out] pkg= (utils) The output package in which to create the function.
    Uses a 3 part format:  libref.catalog.package

**/

%macro mcf_string2file(wrap=NO
  ,insert_cmplib=NO
  ,lib=WORK
  ,cat=SASJS
  ,pkg=UTILS
)/*/STORE SOURCE*/;

%if &wrap=YES  %then %do;
  proc fcmp outlib=&lib..&cat..&pkg;
%end;

function mcf_string2file(filepath $, string $, mode $);
  if mode='APPEND' then fmode='a';
  else fmode='o';
  length fref $8;
  rc=filename(fref,filepath);
  if (rc ne 0) then return( -1 );
  fid = fopen(fref,fmode);
  if (fid = 0) then return( -1 );
  rc=fput(fid, string);
  rc=fwrite(fid);
  rc=fclose(fid);
  rc=filename(fref);
  return(0);
endsub;


%if &wrap=YES %then %do;
  quit;
%end;

%if &insert_cmplib=YES %then %do;
  options insert=(CMPLIB=(&lib..&cat));
%end;

%mend mcf_string2file;