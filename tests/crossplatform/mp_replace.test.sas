/**
  @file
  @brief Testing mp_replace.sas macro

  <h4> SAS Macros </h4>
  @li mp_replace.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/


%let test1="&sasjswork/file.txt";
%let str=replace/me;
%let rep=with/this;
data _null_;
  file &test1;
  put 'blahblah';
  put "blahblah&str.blah";
  put 'blahblahblah';
run;
%mp_assertscope(SNAPSHOT)
%mp_replace(&test1, findvar=str, replacevar=rep)
%mp_assertscope(COMPARE)
data _null_;
  infile &test1;
  input;
  if _n_=2 then call symputx('test1result',_infile_);
run;

%mp_assert(
  iftrue=("&test1result" = "blahblah&rep.blah"),
  desc=Checking first replace,
  outds=work.test_results
)


%let test2="&sasjswork/file2.txt";
%let str=%str(replacewith trailing spaces   );
%let rep=%str( with more spaces  );
data _null_;
  file &test2;
  put 'blahblah';
  put "blahblah&str.blah&str. replace &str.X";
  put "blahbreplacewith&str.spacesahblah";
run;
%mp_replace(&test2, findvar=str, replacevar=rep)

data _null_;
  infile &test2;
  input;
  if _n_=2 then call symputx('test2resulta',_infile_);
  if _n_=3 then call symputx('test2resultb',_infile_);
run;

%mp_assert(
  iftrue=("&test2resulta" = "blahblah&rep.blah&rep. replace &rep.X"),
  desc=Checking second replace 2nd row,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test2resultb" = "blahbreplacewith&rep.spacesahblah"),
  desc=Checking second replace 3rd row,
  outds=work.test_results
)


%let test3="&sasjswork/file3.txt";
%let str=%str(replace.string.with.dots   );
%let rep=%str( more.dots);
data _null_;
  file &test3;
  put 'blahblah';
  put "blahblah&str.blah&str. replace &str.X";
  put "blahbreplacewith&str.spacesahblah";
run;
%mp_replace(&test3, findvar=str, replacevar=rep)

data _null_;
  infile &test3;
  input;
  if _n_=2 then call symputx('test3resulta',_infile_);
  if _n_=3 then call symputx('test3resultb',_infile_);
run;

%mp_assert(
  iftrue=("&test3resulta" = "blahblah&rep.blah&rep. replace &rep.X"),
  desc=Checking third replace 2nd row (dots),
  outds=work.test_results
)
%mp_assert(
  iftrue=("&test3resultb" = "blahbreplacewith&rep.spacesahblah"),
  desc=Checking third replace 3rd row (dots),
  outds=work.test_results
)
