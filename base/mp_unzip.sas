/**
  @file mp_unzip.sas
  @brief Unzips a zip file
  @details Opens the zip file and copies all the contents to another directory.
  It is not possible to retain permissions / timestamps, also the BOF marker
  is lost so it cannot extract binary files.

  Usage:

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %mp_unzip(ziploc="/some/file.zip",outdir=/some/folder)

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mf_getuniquefileref.sas

  @param ziploc= Fileref or quoted full path to zip file ("/path/to/file.zip")
  @param outdir= (%sysfunc(pathname(work))) Directory in which to write the
    outputs (created if non existant)

  @version 9.4
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_unzip(
  ziploc=
  ,outdir=%sysfunc(pathname(work))
)/*/STORE SOURCE*/;

%local f1 f2 f3;
%let f1=%mf_getuniquefileref();
%let f2=%mf_getuniquefileref();
%let f3=%mf_getuniquefileref();

/* Macro variable &datazip would be read from the file */
filename &f1 ZIP &ziploc;

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
filename &f1 clear;

/* loop through each entry and either create the subfolder or extract member */
%mf_mkdir(&outdir)
data _null_;
  set &syslast;
  if isFolder then call execute('%mf_mkdir(&outdir/'!!memname!!')');
  else do;
    call execute(
      cats('filename &f2 zip &ziploc member="',memname,'" recfm=n;')
    );
    call execute('filename &f3 "&outdir/'!!trim(memname)!!'" recfm=n;');
    call execute('data _null_; rc=fcopy("&f2","&f3");run;');
    call execute('filename &f2 clear; filename &f3 clear;');
  end;
run;

%mend mp_unzip;