/**
  @file
  @brief Testing ml_gsubfile macro

  <h4> SAS Macros </h4>
  @li ml_gsubfile.sas
  @li mf_mkdir.sas
  @li mp_assert.sas

  @details The macro substitutes the value of the macro variable named by
  patternvar with the value of the one named by replacevar, in place.

**/

%let root=%sysfunc(pathname(work))/gsub;
%mf_mkdir(&root)
%let target=&root/seed.txt;
%let pattern=WORLD;
%let repl=there;

data _null_;
  file "&target";
  put 'hello WORLD';
run;

%let file=&target;
%let outfile=0;
%let patternvar=pattern;
%let replacevar=repl;

%ml_gsubfile()

%let subbed=0;
%let stale=0;

data _null_;
  infile "&target" truncover;
  input;
  if index(_infile_,'there')>0 then call symputx('subbed',1,'g');
  if index(_infile_,'WORLD')>0 then call symputx('stale',1,'g');
run;

%mp_assert(
  iftrue=(&subbed=1),
  desc=Checking that the pattern is replaced in the file,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&stale=0),
  desc=Checking that no copy of the original pattern is left,
  outds=work.test_results
)
