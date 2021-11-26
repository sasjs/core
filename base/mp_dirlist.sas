/**
  @file
  @brief Returns all files and subdirectories within a specified parent
  @details When used with getattrs=NO, is not OS specific (uses dopen / dread).

  Credit for the rename approach:
  https://communities.sas.com/t5/SAS-Programming/SAS-Function-to-convert-string-to-Legal-SAS-Name/m-p/27375/highlight/true#M5003


  usage:

      %mp_dirlist(path=/some/location, outds=myTable, maxdepth=MAX)

      %mp_dirlist(outds=cwdfileprops, getattrs=YES)

      %mp_dirlist(fref=MYFREF)

  @warning In a Unix environment, the existence of a named pipe will cause this
  macro to hang.  Therefore this tool should be used with caution in a SAS 9 web
  application, as it can use up all available multibridge sessions if requests
  are resubmitted.
  If anyone finds a way to positively identify a named pipe using SAS (without
  X CMD) do please raise an issue!


  @param [in] path= for which to return contents
  @param [in] fref= Provide a DISK engine fileref as an alternative to PATH
  @param [in] maxdepth= (0) Set to a positive integer to indicate the level of
    subdirectory scan recursion - eg 3, to go `./3/levels/deep`.  For unlimited
    recursion, set to MAX.
  @param [out] outds= the output dataset to create
  @param [out] getattrs= (NO)  If getattrs=YES then the doptname / foptname
    functions are used to scan all properties - any characters that are not
    valid in a SAS name (v7) are simply stripped, and the table is transposed
    so theat each property is a column and there is one file per row.  An
    attempt is made to get all properties whether a file or folder, but some
    files/folders cannot be accessed, and so not all properties can / will be
    populated.


  @returns outds contains the following variables:
    - directory (containing folder)
    - file_or_folder (file / folder)
    - filepath (path/to/file.name)
    - filename (just the file name)
    - ext (.extension)
    - msg (system message if any issues)
    - level (depth of folder)
    - OS SPECIFIC variables, if <code>getattrs=</code> is used.

  <h4> SAS Macros </h4>
  @li mp_dropmembers.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mp_dirlist(path=%sysfunc(pathname(work))
    , fref=0
    , outds=work.mp_dirlist
    , getattrs=NO
    , maxdepth=0
    , level=0 /* The level of recursion to perform.  For internal use only. */
)/*/STORE SOURCE*/;
%let getattrs=%upcase(&getattrs)XX;

/* temp table */
%local out_ds;
data;run;
%let out_ds=%str(&syslast);

/* drop main (top) table if it exists */
%if &level=0 %then %do;
  %mp_dropmembers(&outds, libref=WORK)
%end;

data &out_ds(compress=no
    keep=file_or_folder filepath filename ext msg directory level
  );
  length directory filepath $500 fref fref2 $8 file_or_folder $6 filename $80
    ext $20 msg $200;
  retain level &level;
  %if &fref=0 %then %do;
    rc = filename(fref, "&path");
  %end;
  %else %do;
    fref="&fref";
    rc=0;
  %end;
  if rc = 0 then do;
    did = dopen(fref);
    directory=dinfo(did,'Directory');
    if did=0 then do;
      putlog "NOTE: This directory is empty - " directory;
      msg=sysmsg();
      put _all_;
      stop;
    end;
    rc = filename(fref);
  end;
  else do;
    msg=sysmsg();
    put _all_;
    stop;
  end;
  dnum = dnum(did);
  do i = 1 to dnum;
    filename = dread(did, i);
    filepath=cats(directory,'/',filename);
    rc = filename(fref2,filepath);
    midd=dopen(fref2);
    dmsg=sysmsg();
    if did > 0 then file_or_folder='folder';
    rc=dclose(midd);
    midf=fopen(fref2);
    fmsg=sysmsg();
    if midf > 0 then file_or_folder='file';
    rc=fclose(midf);

    if index(fmsg,'File is in use') or index(dmsg,'is not a directory')
      then file_or_folder='file';
    else if index(fmsg,'Insufficient authorization') then file_or_folder='file';
    else if file_or_folder='' then file_or_folder='locked';

    if file_or_folder='file' then do;
      ext = prxchange('s/.*\.{1,1}(.*)/$1/', 1, filename);
      if filename = ext then ext = ' ';
    end;
    else do;
      ext='';
      file_or_folder='folder';
    end;
    output;
  end;
  rc = dclose(did);
  stop;
run;

%if %substr(&getattrs,1,1)=Y %then %do;
  data &out_ds;
    set &out_ds;
    length infoname infoval $60 fref $8;
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
  proc transpose data=&out_ds out=&out_ds(drop=_:);
    id sasname;
    var infoval;
    by filepath file_or_folder filename ext ;
  run;
%end;

/* update main table */
proc append base=&outds data=&out_ds;
run;

data &outds;
  set &outds(where=(filepath ne ''));
run;

/* recursive call */
%if &maxdepth>&level or &maxdepth=MAX %then %do;
  data _null_;
    set &out_ds;
    where file_or_folder='folder';
    code=cats('%nrstr(%mp_dirlist(path=',filepath,",outds=&outds"
      ,",getattrs=&getattrs,level=%eval(&level+1),maxdepth=&maxdepth))");
    put code=;
    call execute(code);
  run;
%end;

/* tidy up */
proc sql;
drop table &out_ds;

%mend mp_dirlist;