/**
  @file
  @brief Testing mp_hashdirectory.sas macro


  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_hashdirectory.sas

**/

/* set up a directory to hash */
%let fpath=%sysfunc(pathname(work))/testdir;

%mf_mkdir(&fpath)
%mf_mkdir(&fpath/sub1)
%mf_mkdir(&fpath/sub2)
%mf_mkdir(&fpath/sub1/subsub)

/* note - the path in the file means the hash is different in each run */
%macro makefile(path,name);
  data _null_;
    file "&path/&name" termstr=lf;
    put "This file is located at:";
    put "&path";
    put "and it is called:";
    put "&name";
  run;
%mend makefile;

%macro spawner(path);
  %do x=1 %to 5;
    %makefile(&path,file&x..txt)
  %end;
%mend spawner;

%spawner(&fpath)
%spawner(&fpath/sub1)
%spawner(&fpath/sub1/subsub)


%mp_assertscope(SNAPSHOT)
%mp_hashdirectory(&fpath,outds=work.hashes,maxdepth=MAX)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=No errors,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.hashes)=19),
  desc=record created for each entry,
  outds=work.test_results
)

proc sql;
select count(*) into: misscheck
  from work.hashes
  where file_hash is missing;

%mp_assert(
  iftrue=(&misscheck=1),
  desc=Only one missing hash - the empty directory,
  outds=work.test_results
)

data _null_;
  set work.hashes;
  if directory=file_path then call symputx('tophash',file_hash);
run;

%mp_assert(
  iftrue=(%length(&tophash)=32),
  desc=ensure valid top level hash created,
  outds=work.test_results
)

/* now change a file and re-hash */
data _null_;
  file "&fpath/sub1/subsub/file1.txt" termstr=lf;
  put "This file has changed!";
run;

%mp_hashdirectory(&fpath,outds=work.hashes2,maxdepth=MAX)

data _null_;
  set work.hashes2;
  if directory=file_path then call symputx('tophash2',file_hash);
run;

%mp_assert(
  iftrue=(&tophash ne &tophash2),
  desc=ensure the changing of the hash results in a new value,
  outds=work.test_results
)

/* now change it back and see if it matches */
data _null_;
  file "&fpath/sub1/subsub/file1.txt" termstr=lf;
    put "This file is located at:";
    put "&fpath/sub1/subsub";
    put "and it is called:";
    put "file1.txt";
  run;
run;

%mp_hashdirectory(&fpath,outds=work.hashes3,maxdepth=MAX)

data _null_;
  set work.hashes3;
  if directory=file_path then call symputx('tophash3',file_hash);
run;

%mp_assert(
  iftrue=(&tophash=&tophash3),
  desc=ensure the same files result in the same hash,
  outds=work.test_results
)

/* dump contents for debugging */
data _null_;
  set work.hashes;
  put file_hash file_path;
run;
data _null_;
  set work.hashes2;
  put file_hash file_path;
run;
