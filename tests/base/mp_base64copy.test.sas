/**
  @file
  @brief Testing mp_base64copy.sas macro

  <h4> SAS Macros </h4>
  @li mp_base64copy.sas
  @li mp_assert.sas

**/


/* TEST 1 - regular base64 decode */

%let string1=base ik ally;
filename tmp temp;
data _null_;
  file tmp;
  put "&string1";
run;
%mp_base64copy(inref=tmp, outref=myref, action=ENCODE)

data _null_;
  infile myref;
  input;
  put _infile_;
run;
%mp_base64copy(inref=myref, outref=mynewref, action=DECODE)
data _null_;
  infile mynewref lrecl=5000;
  input;
  put _infile_;
  call symputx('string1_check',_infile_);
  stop;
run;
%mp_assert(
  iftrue=("&string1"="&string1_check"),
  desc=Basic String Compare,
  outds=work.test_results
)


/* multibyte string check */

filename tmp2 temp lrecl=500;
data _null_;
  file tmp2;
  put "'╤', '╔', '╗', '═', '╧', '╚', '╝', '║', '╟', '─', '┼', '║', '╢', '│'";
run;
%mp_base64copy(inref=tmp2, outref=myref2, action=ENCODE)

%mp_base64copy(inref=myref2, outref=newref2, action=DECODE)
data _null_;
  infile newref2 lrecl=5000;
  input;
  list;
  /* do not print the string to the log else viya 3.5 throws exception */
  if trim(_infile_)=
    "'╤', '╔', '╗', '═', '╧', '╚', '╝', '║', '╟', '─', '┼', '║', '╢', '│'"
  then call symputx('check2',1);
  else call symputx('check2',0);
  stop;
run;
%mp_assert(
  iftrue=("&check2"="1"),
  desc=Double Byte String Compare,
  outds=work.test_results
)