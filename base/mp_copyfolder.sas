/**
  @file
  @brief A macro to recursively copy a directory
  @details Performs a recursive directory listing then works from top to bottom
    copying files and creating subdirectories.

  Usage:

      %let rootdir=%sysfunc(pathname(work))/demo;
      %let copydir=%sysfunc(pathname(work))/demo_copy;
      %mf_mkdir(&rootdir)
      %mf_mkdir(&rootdir/subdir)
      %mf_mkdir(&rootdir/subdir/subsubdir)
      data "&rootdir/subdir/example.sas7bdat";
      run;

      %mp_copyfolder(&rootdir,&copydir)

  @param [in] source Unquoted path to the folder to copy from.
  @param [out] target Unquoted path to the folder to copy to.
  @param [in] copymax= (MAX) Set to a positive integer to indicate the level of
    subdirectory copy recursion - eg 3, to go `./3/levels/deep`.  For unlimited
    recursion, set to MAX.

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mf_isdir.sas
  @li mf_mkdir.sas
  @li mp_abort.sas
  @li mp_dirlist.sas

  <h4> Related Macros </h4>
  @li mp_copyfolder.test.sas

**/

%macro mp_copyfolder(source,target,copymax=MAX);

  %mp_abort(iftrue=(%mf_isdir(&source)=0)
    ,mac=&sysmacroname
    ,msg=%str(Source dir does not exist (&source))
  )

  %mf_mkdir(&target)

  %mp_abort(iftrue=(%mf_isdir(&target)=0)
    ,mac=&sysmacroname
    ,msg=%str(Target dir could not be created (&target))
  )

  /* prep temp table */
  %local tempds;
  %let tempds=%mf_getuniquename();

  /* recursive directory listing */
  %mp_dirlist(path=&source,outds=work.&tempds,maxdepth=&copymax)

  /* create folders and copy content */
  data _null_;
    length msg $200;
    call missing(msg);
    set work.&tempds;
    if _n_ = 1 then dpos+sum(length(directory),2);
    filepath2="&target/"!!substr(filepath,dpos);
    if file_or_folder='folder' then call execute('%mf_mkdir('!!filepath2!!')');
    else do;
      length fref1 fref2 $8;
      rc1=filename(fref1,filepath,'disk','recfm=n');
      rc2=filename(fref2,filepath2,'disk','recfm=n');
      if fcopy(fref1,fref2) ne 0 then do;
        msg=sysmsg();
        putlog 'ERR' +(-1) "OR: Unable to copy " filepath " to " filepath2;
        putlog msg=;
      end;
    end;
    rc=filename(fref1);
    rc=filename(fref2);
  run;

  /* tidy up */
  proc sql;
  drop table work.&tempds;

%mend mp_copyfolder;
