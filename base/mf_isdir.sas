/**
  @file
  @brief Checks whether a path is a valid directory
  @details
  Usage:

      %let isdir=%mf_isdir(/tmp);

  With thanks and full credit to Andrea Defronzo -
  https://www.linkedin.com/in/andrea-defronzo-b1a47460/

  @param path full path of the file/directory to be checked

  @return output returns 1 if path is a directory, 0 if it is not

  @version 9.2
**/

%macro mf_isdir(path
)/*/STORE SOURCE*/;
  %local rc did is_directory fref_t;

  %let is_directory = 0;
  %let rc = %sysfunc(filename(fref_t, %superq(path)));
  %let did = %sysfunc(dopen(&fref_t.));
  %if &did. ^= 0 %then %do;
    %let is_directory = 1;
    %let rc = %sysfunc(dclose(&did.));
  %end;
  %let rc = %sysfunc(filename(fref_t));

  &is_directory

%mend;