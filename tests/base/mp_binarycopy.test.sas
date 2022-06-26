/**
  @file
  @brief Testing mp_binarycopy.sas macro

  <h4> SAS Macros </h4>
  @li mp_binarycopy.sas
  @li mp_assert.sas
  @li mp_hashdataset.sas

**/


/* TEST 1 - regular file copy */
%let string1=test1;
filename tmp temp;
filename myref temp;
data _null_;
  file tmp;
  put "&string1";
run;
%mp_binarycopy(inref=tmp, outref=myref)
data _null_;
  infile myref;
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


/* TEST 2 - File append */
%let string2=test2;
%let path2=%sysfunc(pathname(work))/somefile.txt;
data _null_;
  file "&path2";
  put "&string2";
run;
%mp_binarycopy(inloc="&path2", outref=myref, mode=APPEND)
data _null_;
  infile myref;
  input;
  put _infile_;
  if _n_=2 then call symputx('string2_check',_infile_);
run;
%mp_assert(
  iftrue=("&string2"="&string2_check"),
  desc=Append Check (file to ref),
  outds=work.test_results
)

/* TEST 3 - File create (ref to existing file) */
%let string3=test3;
%let path3=%sysfunc(pathname(work))/somefile3.txt;
filename tmp3 temp;
data _null_;
  file tmp3;
  put "&string3";
run;
data _null_;
  file "&path3";
  put "this should not be returned";
run;
%mp_binarycopy(inref=tmp3, outloc="&path3")
data _null_;
  infile "&path3";
  input;
  put _infile_;
  if _n_=1 then call symputx('string3_check',_infile_);
run;
%mp_assert(
  iftrue=("&string3"="&string3_check"),
  desc=Append Check (ref to existing file),
  outds=work.test_results
)

/* TEST 4 - File append (ref to file) */
%let string4=test4;
%let string4_check=;
filename tmp4 temp;
data _null_;
  file tmp4;
  put "&string4";
run;
%mp_binarycopy(inref=tmp4, outloc="&path3",mode=APPEND)
data _null_;
  infile "&path3";
  input;
  put _infile_;
  if _n_=2 then call symputx('string4_check',_infile_);
run;
%mp_assert(
  iftrue=("&string4"="&string4_check"),
  desc=Append Check (ref to file),
  outds=work.test_results
)

/* test 5 - ensure copy works for binary characters */
/* do this backwards to avoid null chars in JSON preview */
data work.test5;
do i=255 to 1 by -1;
  str=byte(i);
  output;
end;
run;
/* get an md5 hash of the ds */
%mp_hashdataset(work.test5,outds=myhash)

/* copy it */
%mp_binarycopy(inloc="%sysfunc(pathname(work))/test5.sas7bdat",
  outloc="%sysfunc(pathname(work))/test5copy.sas7bdat"
)

/* get an md5 hash of the copied ds */
%mp_hashdataset(work.test5copy,outds=myhash2)

/* compare hashes */
%let test5a=0;
%let test5b=1;
data _null_;
  set myhash;
  call symputx('test5a',hashkey);
run;
data _null_;
  set myhash2;
  call symputx('test5b',hashkey);
run;
%mp_assert(
  iftrue=("&test5a"="&test5b"),
  desc=Ensuring binary copy works on binary characters,
  outds=work.test_results
)
