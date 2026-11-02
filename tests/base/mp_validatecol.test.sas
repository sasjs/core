/**
  @file
  @brief Testing mp_validatecol.sas macro

  <h4> SAS Macros </h4>
  @li mp_assertdsobs.sas
  @li mp_validatecol.sas

**/


/**
  * Test 1 - LIBDS
  */
data test1;
  infile datalines4 dsd;
  input;
  libds=_infile_;
  %mp_validatecol(libds,LIBDS,is_libds)
  if is_libds=1;
datalines4;
some.libname
!lib.blah
%abort
definite.ok
not.ok!
nineletrs._
;;;;
run;
%mp_assertdsobs(work.test1,
  desc=Testing LIBDS,
  test=EQUALS 2,
  outds=work.test_results
)

/**
  * Test 2 - ISNUM
  */
data test2;
  infile datalines4 dsd;
  input;
  infile=_infile_;
  %mp_validatecol(infile,ISNUM,is_numeric)
  if is_numeric=1;
datalines4;
1
0001
1e6
-44
above are good
the rest are bad
%abort
1&somethingverybad.
&
+-1
;;;;
run;
%mp_assertdsobs(work.test2,
  desc=Test2 - ISNUM,
  test=EQUALS 4,
  outds=work.test_results
)

/**
  * Test 3 - FORMAT
  */
data test3;
  infile datalines4 dsd;
  input;
  infile=_infile_;
  %mp_validatecol(infile,FORMAT,is_format)
  if is_format=1;
datalines4;
$.
$format.
$format12.2
somenum.
somenum12.4
4.
8.2
12.
above are good
the rest are bad
%abort
1&somethingverybad.
&
+-1
.
a.A
$format12.1b
$format12.1b1
1
12
0
;;;;
run;
%mp_assertdsobs(work.test3,
  desc=Test3 - ISFORMAT,
  test=EQUALS 8,
  outds=work.test_results
)

/**
  * Test 4 - ISINT
  */
data test4;
  infile datalines4 dsd;
  input;
  infile=_infile_;
  %mp_validatecol(infile,ISINT,is_integer)
  if is_integer=1;
datalines4;
1
1234
-134
-1.0
1.0
0
above are good
the rest are bad
0.1
1.1
-0.001
%abort
1&somethingverybad.
&
+-1
.
a.A
$format12.1b
$format12.1b1
;;;;
run;
%mp_assertdsobs(work.test4,
  desc=Test4 - ISFORMAT,
  test=EQUALS 6,
  outds=work.test_results
)

/**
  * Test 5 - ISLIB
  */
data test5;
  infile datalines4 dsd;
  input;
  inf=_infile_;
  %mp_validatecol(inf,ISLIB,islib)
  if islib=1;
datalines4;
some
!lib
%abort
definite
2fail
nineletrs
.failalso
_valid
;;;;
run;
%mp_assertdsobs(work.test5,
  desc=Testing ISLIB,
  test=EQUALS 3,
  outds=work.test_results
)

/**
  * Test 6 - ISNAME
  */
data test6;
  infile datalines4 dsd;
  input;
  inf=_infile_;
  %mp_validatecol(inf,ISNAME,isname)
  if isname=1;
datalines4;
somename
_underscore_start
name_with_32_characters_exactly_
UPPERCASE
MixedCase99
above are ok - below are not ok
name_with_33_characters_exactly_x
!name
%abort
2fail
.fail
has spaces
has-hyphen
has.dot
&badness
;;;;
run;
%mp_assertdsobs(work.test6,
  desc=Testing ISNAME,
  test=EQUALS 5,
  outds=work.test_results
)

/**
  * Test 5 - ISPATH
  *
  * Shape only: /tmp passes on Unix whether or not it is mounted, and a
  * relative path never passes.  Both platform shapes are in the fixture so the
  * branch that runs is always the one being asserted - four of these are
  * Windows-only (drive, forward-slash drive, UNC, and a second drive), and on
  * Windows none of the Unix absolutes pass.
  */
data test5;
  infile datalines4 truncover;
  length pathval $1000;
  input pathval $char1000.;
  %mp_validatecol(pathval,ISPATH,is_path)
  if is_path=1;
datalines4;
/tmp
/
/tmp/a b/c-d_e.txt
tmp
./tmp
a/b
C:\folder
C:/folder
\\server\share
D:\data\2024
C:folder
\folder
C:\a?b
C:\a"b
;;;;
run;

data _null_;
  if "%upcase(&sysscp)" in ('WIN','DNTHOST') then call symputx('pathexp',4,'g');
  else call symputx('pathexp',3,'g');
run;

%mp_assertdsobs(work.test5,
  desc=Test5 - ISPATH keeps only absolute paths,
  test=EQUALS &pathexp,
  outds=work.test_results
)

/**
  * Test 6 - ISNAME
  */
data test6;
  infile datalines4 dsd;
  input;
  inf=_infile_;
  %mp_validatecol(inf,ISNAME,isname)
  if isname=1;
datalines4;
somename
_underscore_start
name_with_32_characters_exactly_
UPPERCASE
MixedCase99
above are ok - below are not ok
name_with_33_characters_exactly_x
!name
%abort
2fail
.fail
has spaces
has-hyphen
has.dot
&badness
;;;;
run;
%mp_assertdsobs(work.test6,
  desc=Testing ISNAME,
  test=EQUALS 5,
  outds=work.test_results
)

/**
  * Test 5 - ISPATH
  *
  * Shape only: /tmp passes on Unix whether or not it is mounted, and a
  * relative path never passes.  The fixture is the same everywhere; the count
  * differs by platform (a leading / is not absolute on Windows).
  */
data test5;
  infile datalines4 dsd truncover;
  length pathval $1000;
  input pathval $char1000.;
  %mp_validatecol(pathval,ISPATH,is_path)
  if is_path=1;
datalines4;
/tmp
/
/tmp/a b/c-d_e.txt
tmp
./tmp
a/b
;;;;
run;

data _null_;
  if "%upcase(&sysscp)" in ('WIN','DNTHOST') then call symputx('pathexp',0,'g');
  else call symputx('pathexp',3,'g');
run;

%mp_assertdsobs(work.test5,
  desc=Test5 - ISPATH keeps only absolute paths,
  test=EQUALS &pathexp,
  outds=work.test_results
)
