/**
  @file
  @brief Testing mp_zip macro

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mp_assert.sas
  @li mp_zip.sas
  @li mp_unzip.sas

**/

%let work=%sysfunc(pathname(work));
%let root=&work/zipme;

/* TEST 1 - zip a file */
%mf_mkdir(&root)

data _null_;
  file "&root/test.txt";
  put "houston, this is a test";
run;

%mp_zip(in=&root/test.txt
  ,type=FILE
  ,outpath=&work
  ,outname=myFile
)

%mp_unzip(ziploc="&work/myFile.zip",outdir=&work)

data _null_;
  infile "&work/test.txt";
  input;
  call symputx('content1',_infile_);
  putlog _infile_;
run;

%mp_assert(
  iftrue=(
    %str(&content1)=%str(houston, this is a test)
  ),
  desc=Checking if file zip / unzip works,
  outds=work.test_results
)

/* TEST 2 - zip a dataset of files */
data _null_;
  file "&root/test2.txt";
  put "houston, this is test2";
run;
libname tmp "&root";
data tmp.test;
  filepath="&root/test2.txt";
run;

%mp_zip(in=tmp.test
  ,incol=filepath
  ,type=DATASET
  ,outpath=&work
  ,outname=myFile2
)

%mp_unzip(ziploc="&work/myFile2.zip",outdir=&work)

data _null_;
  infile "&work/test2.txt";
  input;
  call symputx('content2',_infile_);
  putlog _infile_;
run;

%mp_assert(
  iftrue=(
    %str(&content2)=%str(houston, this is test2)
  ),
  desc=Checking if file zip / unzip from a dataset works,
  outds=work.test_results
)

/* TEST 3 - zip a dataset of files */
%mf_mkdir(&work/out3)

%mp_zip(in=&root
  ,type=DIRECTORY
  ,outpath=&work
  ,outname=myFile3
)

%mp_unzip(ziploc="&work/myFile3.zip",outdir=&work/out3)

data _null_;
  infile "&work/out3/test.txt";
  input;
  call symputx('content3a',_infile_);
  putlog _infile_;
run;
data _null_;
  infile "&work/out3/test2.txt";
  input;
  call symputx('content3b',_infile_);
  putlog _infile_;
run;

%mp_assert(
  iftrue=(
    %str(&content3a)=%str(houston, this is a test)
    and
    %str(&content3b)=%str(houston, this is test2)
  ),
  desc=Checking if file zip / unzip from a directory works,
  outds=work.test_results
)


