/**
  @file
  @brief A macro to delete a directory
  @details Will delete all folder content (including subfolder content) and
    finally, the folder itself.

  @param path Unquoted path to the folder to delete.

  <h4> SAS Macros </h4>
  @li mp_dirlist.sas

**/

%macro mp_deletefolder(folder);
  %let rc = %sysfunc(filename(fid,&folder));
  %if &rc %then %do;
    %put rc = &rc ;
    %put %sysfunc(sysmsg());
  %end;
  %else %do;
    %let rc  = %sysfunc(fexist(&fid));
    %if not &rc %then %put Folder does not exist. ;
    %else %if &rc %then %do;
      %mp_dirlist(path=&folder,outds=mp_dirlist);
      %let dsid = %sysfunc(open(mp_dirlist));
      %let nobs = %sysfunc(attrn(&dsid,nobs));
      %let rc   = %sysfunc(close(&dsid));
      %if &nobs %then %do;
        proc sort data=mp_dirlist;
          by descending level;
        run;
        data _null_;
          set mp_dirlist;
          rc=filename('delfile',filepath);
          rc=fdelete('delfile');
          if rc then do;
            put 'rc = ' rc;
            filepath=trim(filepath);
            put 'Delete of ' filepath 'failed.';
          end;
        run;
        /* tidy up */
        proc sql;
          drop table mp_dirlist;
        quit;
      %end;
      %let rc=%sysfunc(fdelete(&fid));
      %if &rc %then %do;
        %put rc = &rc;
        %put %sysfunc(sysmsg());
      %end;
    %end;
  %end;
%mend mp_deletefolder;