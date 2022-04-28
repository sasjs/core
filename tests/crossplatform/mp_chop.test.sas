/**
  @file
  @brief Testing mp_chop.sas macro

  <h4> SAS Macros </h4>
  @li mp_chop.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* prep input string */
%let src="%sysfunc(pathname(work))/file.txt";
%let str=Chop here!;
%let out1="%sysfunc(pathname(work))/file1.txt";
%let out2="%sysfunc(pathname(work))/file2.txt";
%let out3="%sysfunc(pathname(work))/file3.txt";
%let out4="%sysfunc(pathname(work))/file4.txt";

data _null_;
  file &src;
  put "startsection&str.endsection";
run;


%mp_assertscope(SNAPSHOT)
%mp_chop(&src, matchvar=str, keep=FIRST, outfile=&out1)
%mp_chop(&src, matchvar=str, keep=LAST, outfile=&out2)
%mp_chop(&src, matchvar=str, keep=FIRST, matchpoint=END, outfile=&out3)
%mp_chop(&src, matchvar=str, keep=LAST, matchpoint=END, outfile=&out4)
%mp_assertscope(COMPARE)

data _null_;
  infile &out1 lrecl=200;
  input;
  call symputx('test1',_infile_);
data _null_;
  infile &out2 lrecl=200;
  input;
  call symputx('test2',_infile_);
data _null_;
  infile &out3 lrecl=200;
  input;
  call symputx('test3',_infile_);
data _null_;
  infile &out4 lrecl=200;
  input;
  call symputx('test4',_infile_);
run;

%mp_assert(
  iftrue=("&test1" = "startsection"),
  desc=Checking keep FIRST matchpoint START
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test2" = "Chop here!endsection"),
  desc=Checking keep LAST matchpoint START
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test3" = "startsectionChop here!"),
  desc=Checking keep FIRST matchpoint END
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test4" = "endsection"),
  desc=Checking keep LAST matchpoint END
  outds=work.test_results
)
