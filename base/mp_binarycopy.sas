/**
  @file
  @brief Copy any file using binary input / output streams
  @details Reads in a file byte by byte and writes it back out.  Is an
  os-independent method to copy files.  In case of naming collision, the
  default filerefs can be modified.
  Based on:
  https://stackoverflow.com/questions/13046116/using-sas-to-copy-a-text-file

        %mp_binarycopy(inloc="/home/me/blah.txt", outref=_webout)

  To append to a file, use the mode option, eg:

      filename tmp1 temp;
      filename tmp2 temp;
      data _null_;
        file tmp1;
        put 'stacking';
      run;

      %mp_binarycopy(inref=tmp1, outref=tmp2, mode=APPEND)
      %mp_binarycopy(inref=tmp1, outref=tmp2, mode=APPEND)


  @param [in] inloc quoted "path/and/filename.ext" of the file to be copied
  @param [out] outloc quoted "path/and/filename.ext" of the file to be created
  @param [in] inref (____in) If provided, this fileref will take precedence over
    the `inloc` parameter
  @param [out] outref (____in) If provided, this fileref will take precedence
    over the `outloc` parameter.  It must already exist!
  @param [in] mode (CREATE) Valid values:
    @li CREATE - Create the file (even if it already exists)
    @li APPEND - Append to the file (don't overwrite)

  @returns nothing

  @version 9.2

**/

%macro mp_binarycopy(
    inloc=           /* full path and filename of the object to be copied */
    ,outloc=          /* full path and filename of object to be created */
    ,inref=____in   /* override default to use own filerefs */
    ,outref=____out /* override default to use own filerefs */
    ,mode=CREATE
)/*/STORE SOURCE*/;
  %local mod outmode;
  %if &mode=APPEND %then %do;
    %let mod=mod;
    %let outmode='a';
  %end;
  %else %do;
    %let outmode='o';
  %end;
  /* these IN and OUT filerefs can point to anything */
  %if &inref = ____in %then %do;
    filename &inref &inloc lrecl=1048576 ;
  %end;
  %if &outref=____out %then %do;
    filename &outref &outloc lrecl=1048576 &mod;
  %end;

  /* copy the file byte-for-byte  */
  data _null_;
    infile &inref;
    file &outref;
    input sourcechar $char1. @@;
    format sourcechar hex2.;
    put sourcechar char1. @@;
  run;

  %if &inref = ____in %then %do;
    filename &inref clear;
  %end;
  %if &outref=____out %then %do;
    filename &outref clear;
  %end;
%mend mp_binarycopy;