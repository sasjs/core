/**
  @file
  @brief Deletes a physical file, if it exists
  @details Usage:

      %mf_writefile(&sasjswork/myfile.txt,l1=some content)

      %mf_deletefile(&sasjswork/myfile.txt)

      %mf_deletefile(&sasjswork/myfile.txt)


  @param filepath Full path to the target file

  @returns The return code from the fdelete() invocation

  <h4> Related Macros </h4>
  @li mf_deletefile.test.sas
  @li mf_writefile.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mf_deletefile(file
)/*/STORE SOURCE*/;
  %local rc fref;
  %let rc= %sysfunc(filename(fref,&file));
  %if %sysfunc(fdelete(&fref)) ne 0 %then %put %sysfunc(sysmsg());
  %let rc= %sysfunc(filename(fref));
%mend mf_deletefile;
