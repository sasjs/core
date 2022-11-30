/**
  @file
  @brief Reads the first line of a file using pure macro
  @details Reads the first line of a file and returns it.  Future versions may
  read each line into a macro variable array.

  Generally, reading data into macro variables is not great as certain
  nonprintable characters (such as CR, LF) may be dropped in the conversion.

    Usage:

        %mf_writefile(&sasjswork/myfile.txt,l1=some content,l2=more content)

        %put %mf_readfile(&sasjswork/myfile.txt);


  @param [in] fpath Full path to file to be read

  <h4> Related Macros </h4>
  @li mf_deletefile.sas
  @li mf_writefile.sas
  @li mf_readfile.test.sas

  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mf_readfile(fpath
)/*/STORE SOURCE*/;
%local fref rc fid fcontent;

/* check file exists */
%if %sysfunc(filename(fref,&fpath)) ne 0 %then %do;
  %put &=fref &=fpath;
  %put %str(ERR)OR: %sysfunc(sysmsg());
  %return;
%end;

%let fid=%sysfunc(fopen(&fref,I));

%if &fid=0 %then %do;
  %put %str(ERR)OR: %sysfunc(sysmsg());
  %return;
%end;

%if %sysfunc(fread(&fid)) = 0 %then %do;
  %let rc=%sysfunc(fget(&fid,fcontent,65534));
  &fcontent
%end;

/*
%do %while(%sysfunc(fread(&fid)) = 0);
  %let rc=%sysfunc(fget(&fid,fcontent,65534));
  &fcontent
%end;
*/

%let rc=%sysfunc(fclose(&fid));
%let rc=%sysfunc(filename(&fref));

%mend mf_readfile;
/** @endcond */
