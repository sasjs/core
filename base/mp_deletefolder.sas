/**
  @file
  @brief A macro to delete a directory
  @details Will delete all folder content (including subfolder content) and
    finally, the folder itself.

  Usage:

      %let rootdir=%sysfunc(pathname(work))/demo;
      %mf_mkdir(&rootdir)
      %mf_mkdir(&rootdir/subdir)
      %mf_mkdir(&rootdir/subdir/subsubdir)
      data "&rootdir/subdir/example.sas7bdat";
      run;

      %mp_deletefolder(&rootdir)

  @param [in] folder Unquoted path to the folder to delete.

  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mf_isdir.sas
  @li mp_dirlist.sas

  <h4> Related Macros </h4>
  @li mp_deletefolder.test.sas

**/

%macro mp_deletefolder(folder);
  /* proceed if valid directory */
  %if %mf_isdir(&folder)=1 %then %do;

    /* prep temp table */
    %local tempds;
    %let tempds=%mf_getuniquename();

    /* recursive directory listing */
    %mp_dirlist(path=&folder,outds=work.&tempds, maxdepth=MAX)

    /* sort descending level so can delete folder contents before folders */
    proc sort data=work.&tempds;
      by descending level;
    run;

    /* ensure top level folder is removed at the end */
    proc sql;
    insert into work.&tempds set filepath="&folder";

    /* delete everything */
    data _null_;
      set work.&tempds end=last;
      length fref $8;
      fref='';
      rc=filename(fref,filepath);
      rc=fdelete(fref);
      if rc then do;
        msg=sysmsg();
        put "&sysmacroname:" / rc= / msg= / filepath=;
      end;
      rc=filename(fref);
    run;

    /* tidy up */
    proc sql;
    drop table work.&tempds;

  %end;
  %else %put &sysmacroname: &folder: is not a valid / accessible folder. ;
%mend mp_deletefolder;