/**
  @file
  @brief Performs a text substitution on a file
  @details Reads a file in byte by byte, performing text substiution where a
  match is found.

  This macro can be used on files where lines are longer than 32767.

  If you are running a version of SAS that will allow the io package in LUA, you
  can also use this macro: mp_gsubfile.sas

  Usage:

      %let file=%sysfunc(pathname(work))/file.txt;
      %let str=replace/me;
      %let rep=with/this;
      data _null_;
        file "&file";
        put 'blahblah';
        put "blahblah&str.blah";
        put 'blahblahblah';
      run;
      %mp_replace(file=&file, patternvar=str, replacevar=rep)
      data _null_;
        infile "&file";
        input;
        list;
      run;

  @param file= (0) The file to perform the substitution on
  @param patternvar= Macro variable NAME containing the string to search for
  @param replacevar= Macro variable NAME containing the replacement string
  @param outfile= (mp_rplce) The output fileref to contain the adjusted file.

  <h4> SAS Macros </h4>
  @li ml_gsubfile.sas

  <h4> Related Macros </h4>
  @li mp_gsubfile.test.sas

  @version 9.4
  @author Allan Bowe
**/

%macro mp_replace(file=0,
  patternvar=,
  replacevar=,
  outref=mp_rplce
)/*/STORE SOURCE*/;

  %ml_gsubfile()

%mend mp_replace;
