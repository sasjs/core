/**
  @file
  @brief Returns all files and subdirectories within a specified parent
  @details When used with getattrs=NO, is not OS specific (uses dopen / dread).

  Usage:

      %mp_dirlist(path=/some/location, outds=myTable, maxdepth=MAX)

      %mp_dirlist(outds=cwdfileprops, getattrs=YES)

      %mp_dirlist(fref=MYFREF)

  Entries are classified with the dopen function alone.  The previous
  implementation also used fopen - which blocks when the entry is a named pipe
  (fifo), so a single fifo in a folder was enough to hang the whole session.
  With getattrs=NO that hazard is gone; with getattrs=YES entries are opened to
  read their attributes, so a fifo can still block that mode.

  @note Symlinks are followed.  A symlink that points at one of its own parents
  produces an endless path (a/b/link/b/link/...), so a browse service must
  always pass a finite <code>maxdepth=</code>.

  @param [in] path= (%sysfunc(pathname(work))) Path for which to return contents.
    Pass a blank value to list the platform roots instead - the drives that
    exist on Windows, / on Unix.
  @param [in] fref= (0) Provide a DISK engine fileref as an alternative to PATH
  @param [in] maxdepth= (0) Set to a positive integer to indicate the level of
    subdirectory scan recursion - eg 3, to go `./3/levels/deep`.  For unlimited
    recursion, set to MAX.
  @param [in] maxobs= (0) Maximum number of rows to return.  Zero means no
    limit.  Useful when the folder is expected to be huge and the caller only
    needs a slice of it - no further levels are scanned once the cap is hit.
  @param [in] showparent= (NO) By default, the initial parent directory is not
    part of the results.  Set to YES to include it.  For this record only,
    directory=filepath.
  @param [out] outds= (work.mp_dirlist) The output dataset to create
  @param [out] getattrs= (NO)  If getattrs=YES then the doptname / foptname
    functions are used to scan all properties - any characters that are not
    valid in a SAS name (v7) are simply stripped, and the table is transposed
    so theat each property is a column and there is one file per row.  An
    attempt is made to get all properties whether a file or folder, but some
    files/folders cannot be accessed, and so not all properties can / will be
    populated.
  @param [in] level= (0) Ignored - retained so that callers of previous versions
    do not break.  Recursion is now done in a loop rather than by re-invoking
    the macro.

  @returns outds contains the following variables:
    - directory (containing folder)
    - file_or_folder.  folder when it can be opened as a directory, file when
      it is not a directory (or exists but is not readable, which the copy,
      hash and zip tools treat as a file), and locked when it is listed but
      cannot be opened at all - a broken link, for instance
    - filepath (path/to/file.name)
    - filename (just the file name)
    - ext (.extension)
    - msg (system message if any issues)
    - level (depth of folder)
    - OS SPECIFIC variables, if <code>getattrs=</code> is used.

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_nobs.sas
  @li mp_dropmembers.sas

  <h4> Related Macros </h4>
  @li mp_dirlist.test.sas

  @version 9.2
  @sasjslint {"maxLineLength": 128}
**/

%macro mp_dirlist(path=%sysfunc(pathname(work))
    , fref=0
    , outds=work.mp_dirlist
    , getattrs=NO
    , showparent=NO
    , maxdepth=0
    , maxobs=0
    , level=0 /* deprecated - ignored, kept for backwards compatibility */
)/*/STORE SOURCE*/;
%let getattrs=%upcase(&getattrs)XX;
%let showparent=%upcase(&showparent)XX;

/* the separator belongs to the platform, not to the path text - a unix
  directory name may contain a backslash without that being the separator */
%if "%upcase(&sysscp)"="WIN" or "%upcase(&sysscp)"="DNTHOST" %then %let mpsep=\;
%else %let mpsep=/;

%local lvl nfront total room done mp_roots mpsep;
%local fref1 fref2;

/* the parent can be supplied as a fileref rather than a path */
%if &fref ne 0 %then %let path=%sysfunc(pathname(&fref));

/* MAX is not a number, so convert it (and anything not a digit) to an int */
%if %length(&maxdepth)=0 or %sysfunc(verify(&maxdepth,0123456789))>0 %then %do;
  %if "%upcase(&maxdepth)"="MAX" %then %let maxdepth=2147483647;
  %else %let maxdepth=0;
%end;
%if %length(&maxobs)=0 or %sysfunc(verify(&maxobs,0123456789))>0 %then %let maxobs=0;

/* drop main (top) table if it exists */
%mp_dropmembers(%scan(&outds,-1,.), libref=WORK)

/* an empty table with the target structure - each level is appended to it */
data &outds;
  length directory filepath $2000 file_or_folder $6 filename $255 ext $20
    msg $200 level 8;
  call missing(of _all_);
  stop;
run;

/* a unique fileref per purpose, generated once - only macro vars are local */
%let fref1=%mf_getuniquefileref();
%let fref2=%mf_getuniquefileref();

%let mp_roots=0;
%if %length(&path)=0 %then %let mp_roots=1;

%if &mp_roots=1 %then %do;
  /*
    A blank path is the platform roots: there is no filesystem root on Windows,
    so the drives that exist are the top level, and / is that level on Unix.
  */
  data work.__mp_dirlist_level;
    length directory filepath $2000 file_or_folder $6 filename $255
      ext $20 msg $200 level 8;
    length drive $3 letters $26;
    call missing(of _all_);
    %if "%upcase(&sysscp)"="WIN" or "%upcase(&sysscp)"="DNTHOST" %then %do;
      letters='ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      do i=1 to 26;
        drive=cats(substr(letters,i,1),':');
        rc=filename("&fref1",cats(drive,'\'));
        did=dopen("&fref1");
        if did>0 then do;
          rc=dclose(did);
          directory=drive;
          filepath=cats(drive,'\');
          filename=filepath;
          file_or_folder='folder';
          level=0;
          output;
        end;
        rc=filename("&fref1");
      end;
    %end;
    %else %do;
      directory='';
      filepath='/';
      filename='/';
      file_or_folder='folder';
      level=0;
      output;
    %end;
    keep directory filepath file_or_folder filename ext msg level;
  run;
  proc append base=&outds data=work.__mp_dirlist_level nowarn force;
  run;
  /* the roots are folders, so they are what the next level expands */
  data work.__mp_dirlist_frontier;
    set work.__mp_dirlist_level(where=(file_or_folder='folder'));
    level=1;
    keep filepath level;
  run;
  %let lvl=1;
%end;
%else %do;
  /* level 0 is the parent itself; the path is read with symget so that quotes
    and macro triggers in a folder name are never evaluated as SAS code */
  data work.__mp_dirlist_frontier;
    length filepath $2000 level 8;
    filepath=symget('path');
    level=0;
  run;
  %let lvl=0;
%end;

%let nfront=%sysfunc(coalesce(%mf_nobs(work.__mp_dirlist_frontier),0));
%let done=0;

%do %until(&nfront=0 or &lvl>&maxdepth or &done=1);

  data work.__mp_dirlist_level;
    set work.__mp_dirlist_frontier;
    length directory filepath $2000 file_or_folder $6 filename $255 ext $20
      msg $200 sep $1 prefix $2000 fname $255 dmsg $200;
    drop sep prefix fname dmsg rc did mid i;
    directory=filepath;
    msg='';
    file_or_folder='';
    ext='';
    filename='';
    rc=filename("&fref1", directory);
    did=dopen("&fref1");
    dmsg=sysmsg();
    if did=0 then do;
      /* nothing to list - a parent that vanished between levels, or a path
        that does not exist; the entries that pointed here are already marked
        locked by the level that produced them */
    end;
    else do;
      /* strip any trailing separator, keeping / and drive roots intact */
      do while(length(directory)>1);
        if substr(directory,length(directory),1) not in ('/','\') then leave;
        if length(directory)=3 and substr(directory,2,1)=':' then leave;
        directory=substr(directory,1,length(directory)-1);
      end;
      sep=symget('mpsep');
      if directory='/' or (length(directory)=3 and substr(directory,2,1)=':')
        then prefix=directory;
      else prefix=cats(directory,sep);
      do i=1 to dnum(did);
        fname=dread(did,i);
        filename=fname;
        filepath=cats(prefix,fname);
        msg='';
        ext='';
        /* dopen alone is enough to tell a folder from anything else, and it
          returns immediately for a fifo - fopen would block until a writer
          appeared */
        rc=filename("&fref2",filepath);
        mid=dopen("&fref2");
        if mid>0 then do;
          file_or_folder='folder';
          rc=dclose(mid);
        end;
        else do;
          dmsg=sysmsg();
          if index(dmsg,'is not a directory')>0 then do;
            file_or_folder='file';
            ext=prxchange('s/.*\.{1,1}(.*)/$1/',1,filename);
            if filename=ext then ext=' ';
          end;
          else if index(dmsg,'uthorization')>0 then do;
            /* present but not readable.  It stays a file, as it was before the
              entry test was fixed - the copy, hash and zip tools skip anything
              that is not a file, and a backup that silently omits an unreadable
              file is worse than one that fails on it */
            file_or_folder='file';
            ext=prxchange('s/.*\.{1,1}(.*)/$1/',1,filename);
            if filename=ext then ext=' ';
            msg=dmsg;
          end;
          else do;
            /* listed but not openable at all - a broken link, for instance */
            file_or_folder='locked';
            msg=dmsg;
          end;
        end;
        rc=filename("&fref2");
        output;
      end;
      rc=dclose(did);
    end;
    rc=filename("&fref1");
  run;

  /* trim the level to what is left of the maxobs budget before appending */
  %let total=%sysfunc(coalesce(%mf_nobs(&outds),0));
  %let room=2147483647;
  %if &maxobs>0 %then %let room=%eval(&maxobs-&total);
  %if &room>0 %then %do;
    data work.__mp_dirlist_level;
      set work.__mp_dirlist_level(obs=&room);
    run;
    proc append base=&outds data=work.__mp_dirlist_level force nowarn;
    run;
  %end;

  %let total=%sysfunc(coalesce(%mf_nobs(&outds),0));
  %if &maxobs>0 and &total>=&maxobs %then %let done=1;

  /* the folders of this level become the parents of the next one */
  %let nfront=0;
  %if &done=0 and &lvl<&maxdepth %then %do;
    data work.__mp_dirlist_frontier;
      set work.__mp_dirlist_level(where=(file_or_folder='folder'));
      level=level+1;
      keep filepath level;
    run;
    %let nfront=%sysfunc(coalesce(%mf_nobs(work.__mp_dirlist_frontier),0));
  %end;

  %let lvl=%eval(&lvl+1);

%end;

/* include the starting folder itself, when asked */
%if %substr(&showparent,1,1)=Y %then %do;
  data work.__mp_dirlist_level;
    length directory filepath $2000 file_or_folder $6 filename $255 ext $20
      msg $200 level 8;
    /* the parent is only listed when it can be opened, so a path that does
      not exist stays an empty result even with showparent=YES */
    filepath=symget('path');
    rc=filename("&fref1",filepath);
    did=dopen("&fref1");
    if did>0 then rc=dclose(did);
    rc=filename("&fref1");
    if did=0 then stop;
    directory=filepath;
    do while(length(directory)>1);
      if substr(directory,length(directory),1) not in ('/','\') then leave;
      if length(directory)=3 and substr(directory,2,1)=':' then leave;
      directory=substr(directory,1,length(directory)-1);
    end;
    filepath=directory;
    file_or_folder='folder';
    ext='';
    filename=scan(directory,-1,'/\');
    msg='';
    level=0;
    output;
  run;
  proc append base=&outds data=work.__mp_dirlist_level force nowarn;
  run;
%end;

%if %substr(&getattrs,1,1)=Y %then %do;
  data &outds;
    set &outds;
    length infoname infoval $60 fref $8;
    if _n_=1 then call missing(fref);
    rc=filename(fref,filepath);
    drop rc infoname fid i close fref;
    if file_or_folder='file' then do;
      fid=fopen(fref);
      if fid le 0 then do;
        msg=sysmsg();
        putlog "Could not open file:" filepath fid= ;
        sasname='_MCNOTVALID_';
        output;
      end;
      else do i=1 to foptnum(fid);
        infoname=foptname(fid,i);
        infoval=finfo(fid,infoname);
        sasname=compress(infoname, '_', 'adik');
        if anydigit(sasname)=1 then sasname=substr(sasname,anyalpha(sasname));
        if upcase(sasname) ne 'FILENAME' then output;
      end;
      close=fclose(fid);
    end;
    else do;
      fid=dopen(fref);
      if fid le 0 then do;
        msg=sysmsg();
        putlog "Could not open folder:" filepath fid= ;
        sasname='_MCNOTVALID_';
        output;
      end;
      else do i=1 to doptnum(fid);
        infoname=doptname(fid,i);
        infoval=dinfo(fid,infoname);
        sasname=compress(infoname, '_', 'adik');
        if anydigit(sasname)=1 then sasname=substr(sasname,anyalpha(sasname));
        if upcase(sasname) ne 'FILENAME' then output;
      end;
      close=dclose(fid);
    end;
  run;
  proc sort;
    by filepath sasname;
  proc transpose data=&outds out=&outds(drop=_:);
    id sasname;
    var infoval;
    by filepath file_or_folder filename ext ;
  run;
%end;

data &outds;
  set &outds(where=(filepath ne ''));
run;

/* tidy up */
proc sql noprint;
drop table work.__mp_dirlist_frontier, work.__mp_dirlist_level;
quit;

%mend mp_dirlist;
