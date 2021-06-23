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

  @param ziploc= fileref or quoted full path to zip file ("/path/to/file.zip")
  @param outdir= directory in which to write the outputs (created if non existant)

  @version 9.4
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_unzip(
  ziploc=
  ,outdir=%sysfunc(pathname(work))
)/*/STORE SOURCE*/;

%local fname1 fname2 fname3;
%let fname1=%mf_getuniquefileref();
%let fname2=%mf_getuniquefileref();
%let fname3=%mf_getuniquefileref();

filename &fname1 ZIP &ziploc; * Macro variable &datazip would be read from the file*;

/* Read the "members" (files) from the ZIP file */
data _data_(keep=memname isFolder);
  length memname $200 isFolder 8;
  fid=dopen("&fname1");
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
filename &fname1 clear;

/* loop through each entry and either create the subfolder or extract member */
data _null_;
  set &syslast;
  if isFolder then call execute('%mf_mkdir(&outdir/'!!memname!!')');
  else call execute('filename &fname2 zip &ziploc member='
    !!quote(trim(memname))!!';filename &fname3 "&outdir/'
    !!trim(memname)!!'" recfm=n;data _null_; rc=fcopy("&fname2","&fname3");run;'
    !!'filename &fname2 clear; filename &fname3 clear;');
run;

%mend mp_unzip;