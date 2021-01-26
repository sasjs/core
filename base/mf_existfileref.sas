/**
  @file
  @brief Checks whether a fileref exists
  @details You can probably do without this macro as it is just a one liner.
  Mainly it is here as a convenient way to remember the syntax!

  @param fref the fileref to detect

  @return output Returns 1 if found and 0 if not found.  Note - it is possible
  that the fileref is found, but the file does not (yet) exist. If you need
  to test for this, you may as well use the fileref function directly.

  @version 8
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**/

%macro mf_existfileref(fref
)/*/STORE SOURCE*/;

  %if %sysfunc(fileref(&fref))=0 %then %do;
    1
  %end;
  %else %do;
    0
  %end;

%mend;