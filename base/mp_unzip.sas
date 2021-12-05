/**
  @file mp_unzip.sas
  @brief Unzips a zip file
  @details Opens the zip file and copies all the contents to another directory.
  It is not possible to retain permissions / timestamps, also the BOF marker
  is lost so it cannot extract binary files.

  Usage:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %mp_unzip(ziploc="/some/file.zip",outdir=/some/folder)

  More info:  https://blogs.sas.com/content/sasdummy/2015/05/11/using-filename-zip-to-unzip-and-read-data-files-in-sas/

  @param ziploc= Fileref or quoted full path to zip file ("/path/to/file.zip")
  @param outdir= (%sysfunc(pathname(work))) Directory in which to write the
    outputs (created if non existant)

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mf_getuniquefileref.sas
  @li mp_binarycopy.sas

  @version 9.4
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_unzip(
  ziploc=
  ,outdir=%sysfunc(pathname(work))
)/*/STORE SOURCE*/;

%local f1 f2 ;
%let f1=%mf_getuniquefileref();
%let f2=%mf_getuniquefileref();

/* Macro variable &datazip would be read from the file */
filename &f1 ZIP &ziploc;

/* create target folder */
%mf_mkdir(&outdir)

/* Read the "members" (files) from the ZIP file */
data _data_(keep=memname isFolder);
  length memname $200 isFolder 8;
  fid=dopen("&f1");
  if fid=0 then stop;
  memcount=dnum(fid);
  do i=1 to memcount;
    memname=dread(fid,i);
    /* check for trailing / in folder name */
    isFolder = (first(reverse(trim(memname)))='/');
    output;
  end;
  rc=dclose(fid);
run;

filename &f2 temp;

/* loop through each entry and either create the subfolder or extract member */
data _null_;
  set &syslast;
  file &f2;
  if isFolder then call execute('%mf_mkdir(&outdir/'!!memname!!')');
  else do;
    qname=quote(cats("&outdir/",memname));
    bname=cats('(',memname,')');
    put '/* hat tip: "data _null_" on SAS-L */';
    put 'data _null_;';
    put '  infile &f1 ' bname ' lrecl=256 recfm=F length=length eof=eof unbuf;';
    put '  file ' qname ' lrecl=256 recfm=N;';
    put '  input;';
    put '  put _infile_ $varying256. length;';
    put '  return;';
    put 'eof:';
    put '  stop;';
    put 'run;';
  end;
run;

%inc &f2/source2;

filename &f2 clear;

%mend mp_unzip;
