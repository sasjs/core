/**
  @file
  @brief Checks whether a fileref exists
  @details You can probably do without this macro as it is just a one liner.
  Mainly it is here as a convenient way to remember the syntax!

  For this macro, if the fileref exists but the underlying file does not exist

  @param fref the fileref to detect

  @return output returns 1 if found AND the file exists.  0 is returned if not
  found, and -1 is returned if the fileref is found but the file does not exist.

  @version 8
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mf_existfileref(fref
)/*/STORE SOURCE*/;
  %local result;
  %let result=%sysfunc(fileref(&fref));
  %if  &result>0 %then %do;
    0
  %end;
  %else %if &result=0 %then %do;
    1
  %end;
  %else %do;
    -1
  %end;
%mend;