/**
  @file
  @brief Performs a text substitution on a file
  @details Makes use of the GSUB function in LUA to perform a text substitution
  in a file - either in-place, or writing to a new location.  The benefit of
  using LUA is that the entire file can be loaded into a single variable,
  thereby side stepping the 32767 character limit in a data step.

  Usage:

      %let file=%sysfunc(pathname(work))/file.txt;
      %let str=replace/me;
      %let rep=with/this;
      data _null_;
        file "&file";
        put "&str";
      run;
      %mp_gsubfile(file=&file, pattern=str, replacement=rep)
      data _null_;
        infile "&file";
        input;
        list;
      run;

  @param file= (0) The file to perform the substitution on
  @param patternvar= A macro variable containing the Lua
  [pattern](https://www.lua.org/pil/20.2.html) to search for.  Due to the use
  of special (magic) characters in Lua patterns, it is safer to pass the NAME
  of the macro variable containing the string, rather than the value itself.
  @param replacevar= The name of the macro variable containing the replacement
  _string_.
  @param outfile= (0) The file to write the output to. If zero, then the file
  is overwritten in-place.

  <h4> SAS Macros </h4>
  @li ml_gsubfile.sas

  <h4> Related Macros </h4>
  @li mp_gsubfile.test.sas

  @version 9.4
  @author Allan Bowe
**/

%macro mp_gsubfile(file=0,
  patternvar=,
  replacevar=,
  outfile=0
)/*/STORE SOURCE*/;

  %ml_gsubfile()

%mend mp_gsubfile;
