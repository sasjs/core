/**
  @file
  @brief Creates a zip file
  @details For DIRECTORY usage, will ignore subfolders. For DATASET usage,
    provide a column that contains the full file path to each file to be zipped.

    %mp_zip(in=myzips,type=directory,outname=myDir)
    %mp_zip(in=/my/file/path.txt,type=FILE,outname=myFile)
    %mp_zip(in=SOMEDS,incol=FPATH,type=DATASET,outname=myFile)

  If you are sending zipped output to the _webout destination as part of an STP
  be sure that _debug is not set (else the SPWA will send non zipped content
  as well).

  <h4> SAS Macros </h4>
  @li mp_dirlist.sas

  @param in= unquoted filepath, dataset of files or directory to zip
  @param type= FILE, DATASET, DIRECTORY. (FILE / DATASET not ready yet)
  @param outname= output file to create, without .zip extension
  @param outpath= location for output zip file
  @param incol= if DATASET input, say which column contains the filepath

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_zip(
  in=
  ,type=FILE
  ,outname=FILE
  ,outpath=%sysfunc(pathname(WORK))
  ,incol=
  ,debug=NO
)/*/STORE SOURCE*/;

%let type=%upcase(&type);
%local ds;

ods package open nopf;

%if &type=FILE %then %do;
  ods package add file="&in" mimetype="application/x-compress";
%end;
%else %if &type=DIRECTORY %then %do;
  %mp_dirlist(path=&in,outds=_data_)
  %let ds=&syslast;
  data _null_;
    set &ds;
    length __command $4000;
    if file_or_folder='file';
    command=cats('ods package add file="',filepath
      ,'" mimetype="application/x-compress";');
    call execute(command);
  run;
  /* tidy up */
  %if &debug=NO %then %do;
    proc sql; drop table &ds;quit;
  %end;
%end;
%else %if &type=DATASET %then %do;
  data _null_;
    set &in;
    length __command $4000;
    command=cats('ods package add file="',&incol
      ,'" mimetype="application/x-compress";');
    call execute(command);
  run;
  ods package add file="&in" mimetype="application/x-compress";
%end;


ods package publish archive properties
  (archive_name="&outname..zip" archive_path="&outpath");
ods package close;

%mend;