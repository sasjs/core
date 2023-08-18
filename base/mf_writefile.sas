/**
  @file
  @brief Creates a text file using pure macro
  @details Creates a text file of up to 10 lines.  If further lines are
    desired, feel free to [create an issue](
    https://github.com/sasjs/core/issues/new), or make a pull request!

    The use of PARMBUFF was considered for this macro, but it would have made
    things problematic for writing lines containing commas.

    Usage:

        %mf_writefile(&sasjswork/myfile.txt,l1=some content,l2=more content)
        data _null_;
          infile "&sasjswork/myfile.txt";
          input;
          list;
        run;

  @param [in] fpath Full path to file to be created or appended to
  @param [in] mode= (O) Available options are A or O as follows:
    @li A APPEND mode, writes new records after the current end of the file.
    @li O OUTPUT mode, writes new records from the beginning of the file.
  @param [in] l1= () First line
  @param [in] l2= () Second line (etc through to l10)

  <h4> Related Macros </h4>
  @li mf_writefile.test.sas

  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mf_writefile(fpath,mode=O,l1=,l2=,l3=,l4=,l5=,l6=,l7=,l8=,l9=,l10=
)/*/STORE SOURCE*/;
%local fref rc fid i total_lines;

/* find number of lines by reference to first non-blank param */
%do i=10 %to 1 %by -1;
  %if %str(&&l&i) ne %str() %then %goto continue;
%end;
%continue:
%let total_lines=&i;

%if %sysfunc(filename(fref,&fpath)) ne 0 %then %do;
  %put &=fref &=fpath;
  %put %str(ERR)OR: %sysfunc(sysmsg());
  %return;
%end;

%let fid=%sysfunc(fopen(&fref,&mode));

%if &fid=0 %then %do;
  %put %str(ERR)OR: %sysfunc(sysmsg());
  %return;
%end;

%do i=1 %to &total_lines;
  %let rc=%sysfunc(fput(&fid, &&l&i));
  %let rc=%sysfunc(fwrite(&fid));
%end;
%let rc=%sysfunc(fclose(&fid));
%let rc=%sysfunc(filename(&fref));

%mend mf_writefile;
/** @endcond */