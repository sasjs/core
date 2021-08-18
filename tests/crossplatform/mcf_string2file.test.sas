/**
  @file
  @brief Testing mm_webout macro

  <h4> SAS Macros </h4>
  @li mcf_string2file.sas
  @li mp_assert.sas

**/


%mcf_string2file(wrap=YES, insert_cmplib=YES)

data _null_;
  rc=mcf_string2file(
    "%sysfunc(pathname(work))/newfile.txt"
    , "line1"
    , "APPEND");
  rc=mcf_string2file(
    "%sysfunc(pathname(work))/newfile.txt"
    , "line2"
    , "APPEND");
run;

data _null_;
  infile "%sysfunc(pathname(work))/newfile.txt";
  input;
  if _n_=2 then call symputx('val',_infile_);
run;

%mp_assert(
  iftrue=(%str(&val)=%str(line2)),
  desc=Check if APPEND works
)

data _null_;
  rc=mcf_string2file(
    "%sysfunc(pathname(work))/newfile.txt"
    , "creating"
    , "CREATE");
run;

data _null_;
  infile "%sysfunc(pathname(work))/newfile.txt";
  input;
  if _n_=1 then call symputx('val2',_infile_);
run;

%mp_assert(
  iftrue=(%str(&val2)=%str(creating)),
  desc=Check if CREATE works
)