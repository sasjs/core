/**
  @file
  @brief Testing mf_wordsinstr1butnotstr2 macro

  <h4> SAS Macros </h4>
  @li mf_wordsinstr1butnotstr2.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* basic test, with scope check */
%mp_assertscope(SNAPSHOT)
%let x=%mf_wordsinstr1butnotstr2(str1=xx DOLLAR x $CHAR xxx W MONNAME
  ,str2=ff xx x xxx xxxxxx
);
%mp_assertscope(COMPARE,ignorelist=x)

%mp_assert(
  iftrue=(
    "&x"="DOLLAR $CHAR W MONNAME"
  ),
  desc=Checking basic string,
  outds=work.test_results
)

/* word boundary - var1 should not match var10 or var100 */
%mp_assert(
  iftrue=(
    "%mf_wordsinstr1butnotstr2(str1=var1 var10 var100,str2=var1)"
      ="var10 var100"
  ),
  desc=Checking word boundaries,
  outds=work.test_results
)

/* case sensitivity - dollar does not match DOLLAR */
%mp_assert(
  iftrue=(
    "%mf_wordsinstr1butnotstr2(str1=DOLLAR dollar,str2=DOLLAR)"="dollar"
  ),
  desc=Checking case sensitivity,
  outds=work.test_results
)

/* duplicate words in str1 are preserved */
%mp_assert(
  iftrue=(
    "%mf_wordsinstr1butnotstr2(str1=a a b a,str2=b)"="a a a"
  ),
  desc=Checking duplicate words,
  outds=work.test_results
)

/* when all words match, nothing is returned */
%mp_assert(
  iftrue=(
    "%mf_wordsinstr1butnotstr2(str1=a b,str2=b a)"=""
  ),
  desc=Checking empty result,
  outds=work.test_results
)

/* when str1 is empty, nothing is returned */
%mp_assert(
  iftrue=(
    "%mf_wordsinstr1butnotstr2(str1=,str2=a b)"=""
  ),
  desc=Checking empty str1,
  outds=work.test_results
)

/* when str2 is empty, all of str1 is returned */
%mp_assert(
  iftrue=(
    "%mf_wordsinstr1butnotstr2(str1=a b c,str2=)"="a b c"
  ),
  desc=Checking empty str2 returns all words,
  outds=work.test_results
)

/* build strings containing 1000 variables */
/* str2 is kept to 100 words to avoid excessive macro iterations */
data _null_;
  length str1 str2 expected $32767;
  do i=1 to 1000;
    word=cats('var',i);
    str1=catx(' ',str1,word);
    if mod(i,10)=0 then str2=catx(' ',str2,word);
    else expected=catx(' ',expected,word);
  end;
  call symputx('str1',str1);
  call symputx('str2',str2);
  call symputx('expected',expected);
run;

%mp_assertscope(SNAPSHOT)
%let result=%mf_wordsinstr1butnotstr2(str1=&str1,str2=&str2);
%mp_assertscope(COMPARE,ignorelist=result)

%let count=%sysfunc(countw(&result));

%mp_assert(
  iftrue=(
    "&count"="900"
  ),
  desc=Checking 1000 variable string returns 900 words,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "&result"="&expected"
  ),
  desc=Checking 1000 variable string content,
  outds=work.test_results
)
