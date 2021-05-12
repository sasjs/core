/**
  @file
  @brief Recursively scans a directory tree to get all subfolders and content
  @details
  Usage:

      %mp_tree(dir=/tmp, outds=work.tree)

  Credits:

  Roger Deangelis:
https://communities.sas.com/t5/SAS-Programming/listing-all-files-within-a-directory-and-subdirectories/m-p/332616/highlight/true#M74887

  Tom:
https://communities.sas.com/t5/SAS-Programming/listing-all-files-of-all-types-from-all-subdirectories/m-p/334113/highlight/true#M75419


  @param dir= Directory to be scanned (default=/tmp)
  @param outds= Dataset to create (default=work.mp_tree)

  @returns outds contains the following variables:

    - `dir`: a flag (1/0) to say whether it is a directory or not.  This is not
      reliable - folders that you do not have permission to open will be flagged
      as directories.
    - `ext`: file extension
    - `filename`: file name
    - `dirname`: directory name
    - `fullpath`: directory + file name

  @version 9.2
**/

%macro mp_tree(dir=/tmp
  ,outds=work.mp_tree
)/*/STORE SOURCE*/;

data &outds ;
  length dir 8 ext filename dirname $256 fullpath $512 ;
  call missing(of _all_);
  fullpath = "&dir";
run;

%local sep;
%if &sysscp=WIN or &SYSSCP eq DNTHOST %then %let sep=\;
%else %let sep=/;

data &outds ;
  modify &outds ;
  retain sep "&sep";
  rc=filename('tmp',fullpath);
  dir_id=dopen('tmp');
  dir = (dir_id ne 0) ;
  if dir then dirname=fullpath;
  else do;
    filename=scan(fullpath,-1,sep) ;
    dirname =substrn(fullpath,1,length(fullpath)-length(filename));
    if index(filename,'.')>1 then ext=scan(filename,-1,'.');
  end;
  replace;
  if dir then do;
    do i=1 to dnum(dir_id);
      fullpath=cats(dirname,sep,dread(dir_id,i));
      output;
    end;
    rc=dclose(dir_id);
  end;
  rc=filename('tmp');
run;

%mend;