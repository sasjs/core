/**
  @file ml_gsubfile.sas
  @brief Compiles the gsubfile.lua lua file
  @details Writes gsubfile.lua to the work directory
  and then includes it.
  Usage:

      %ml_gsubfile()

**/

%macro ml_gsubfile();
data _null_;
  file "%sysfunc(pathname(work))/ml_gsubfile.lua";
  put 'local fpath, outpath, file, fcontent ';
  put ' ';
  put '-- configure in / out paths ';
  put 'fpath = sas.symget("file") ';
  put 'outpath = sas.symget("outfile") ';
  put 'if ( outpath == 0 ) ';
  put 'then ';
  put '   outpath=fpath ';
  put 'end ';
  put ' ';
  put '-- open file and perform the substitution ';
  put 'file = io.open(fpath,"r") ';
  put 'fcontent = file:read("*all") ';
  put 'file:close() ';
  put 'fcontent = string.gsub( ';
  put '  fcontent, ';
  put '  sas.symget(sas.symget("patternvar")), ';
  put '  sas.symget(sas.symget("replacevar")) ';
  put ') ';
  put ' ';
  put '-- write the file back out ';
  put 'file = io.open(outpath, "w+") ';
  put 'io.output(file) ';
  put 'io.write(fcontent) ';
  put 'io.close(file) ';
run;

/* ensure big enough lrecl to avoid lua compilation issues */
%local optval;
%let optval=%sysfunc(getoption(lrecl));
options lrecl=1024;

/* execute the lua code by using a .lua extension */
%inc "%sysfunc(pathname(work))/ml_gsubfile.lua" /source2;

options lrecl=&optval;

%mend ml_gsubfile;
