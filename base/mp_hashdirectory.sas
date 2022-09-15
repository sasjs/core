/**
  @file
  @brief Returns a unique hash for each file in a directory
  @details Hashes each file in each directory, and then hashes the hashes to
  create a hash for each directory also.

  This makes use of the new `hashing_file()` and `hashing` functions, available
  since 9.4m6. Interestingly, these can even be used in pure macro, eg:

      %put %sysfunc(hashing_file(md5,/path/to/file.blob,0));

  An example of this logic being applied in JavaScript is available in the
  @sasjs/utils library.

  Usage:

      %let fpath=/some/directory;

      %mp_hashdirectory(&fpath,outds=myhash,maxdepth=2)

      data _null_;
        set work.myhash;
        put (_all_)(=);
      run;

  Whilst files are hashed in their entirety, the logic for creating a folder
  hash is as follows:

  @li Sort the files by filename (case sensitive, uppercase then lower)
  @li Take the first 100 hashes, concatenate and hash
  @li Concatenate this hash with another 100 hashes and hash again
  @li Continue until the end of the folder.  This is the folder hash
  @li If a folder contains other folders, start from the bottom of the tree -
    the folder hashes cascade upwards so you know immediately if there is a
    change in a sub/sub directory
  @li If the folder has no content (empty) then it is ignored. No hash created.

  <h4> SAS Macros </h4>
  @li mp_dirlist.sas

  <h4> Related Files </h4>
  @li mp_hashdataset.sas
  @li mp_hashdirectory.test.sas
  @li mp_md5.sas

  @param [in] inloc Full filepath of the file to be hashed (unquoted)
  @param [in] iftrue= (1=1) A condition under which the macro should be executed
  @param [in] maxdepth= (0) Set to a positive integer to indicate the level of
    subdirectory scan recursion - eg 3, to go `./3/levels/deep`.  For unlimited
    recursion, set to MAX.
  @param [in] method= (MD5) the hashing method to use.  Available options:
    @li MD5
    @li SH1
    @li SHA256
    @li SHA384
    @li SHA512
    @li CRC32
  @param [out] outds= (work.mp_hashdirectory) The output dataset.  Contains:
    @li directory - the parent folder
    @li file_hash - the hash output
    @li hash_duration - how long the hash took (first hash always takes longer)
    @li file_path - /full/path/to/each/file.ext
    @li file_or_folder - contains either "file" or "folder"
    @li level - the depth of the directory (top level is 0)

  @version 9.4m6
  @author Allan Bowe
**/

%macro mp_hashdirectory(inloc,
  outds=work.mp_hashdirectory,
  method=MD5,
  maxdepth=0,
  iftrue=%str(1=1)
)/*/STORE SOURCE*/;

%local curlevel tempds ;

%if not(%eval(%unquote(&iftrue))) %then %return;

/* get the directory listing */
%mp_dirlist(path=&inloc, outds=&outds, maxdepth=&maxdepth, showparent=YES)

/* create the hashes */
data &outds;
  set &outds (rename=(filepath=file_path));
  length FILE_HASH $32 HASH_DURATION 8;
  keep directory file_hash hash_duration file_path file_or_folder level;

  ts=datetime();
  if file_or_folder='file' then do;
    file_hash=hashing_file("&method",cats(file_path),0);
  end;
  hash_duration=datetime()-ts;
run;

proc sort data=&outds ;
  by descending level directory file_path;
run;

data _null_;
  set &outds;
  call symputx('maxlevel',level,'l');
  stop;
run;

/* now hash the hashes to populate folder hashes, starting from the bottom */
%do curlevel=&maxlevel %to 0 %by -1;
  data work._data_ (keep=directory file_hash);
    set &outds;
    where level=&curlevel;
    by descending level directory file_path;
    length str $32767 tmp_hash $32;
    retain str tmp_hash ;
    /* reset vars when starting a new directory */
    if first.directory then do;
      str='';
      tmp_hash='';
      i=0;
    end;
    /* hash each chunk of 100 file paths */
    i+1;
    str=cats(str,file_hash);
    if mod(i,100)=0 or last.directory then do;
      tmp_hash=hashing("&method",cats(tmp_hash,str));
      str='';
    end;
    /* output the hash at directory level */
    if last.directory then do;
      file_hash=tmp_hash;
      output;
    end;
    if last.level then stop;
  run;
  %let tempds=&syslast;
  /* join the hash back into the main table */
  proc sql undo_policy=none;
  create table &outds as
    select a.directory
      ,coalesce(b.file_hash,a.file_hash) as file_hash
      ,a.hash_duration
      ,a.file_path
      ,a.file_or_folder
      ,a.level
    from &outds a
    left join &tempds b
    on a.file_path=b.directory
    order by level desc, directory, file_path;
  drop table &tempds;
%end;

%mend mp_hashdirectory;
