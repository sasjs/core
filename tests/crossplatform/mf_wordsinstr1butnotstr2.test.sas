/**
  @file
  @brief Testing mf_wordsinstr1butnotstr2 macro

  <h4> SAS Macros </h4>
  @li mf_wordsinstr1butnotstr2.sas
  @li mp_assert.sas

**/

%let x=%mf_wordsinstr1butnotstr2(str1=xx DOLLAR x $CHAR xxx W MONNAME
  ,str2=ff xx x xxx xxxxxx
);
%mp_assert(
  iftrue=(
    "&x"="DOLLAR $CHAR W MONNAME"
  ),
  desc=Checking basic string,
  outds=work.test_results
)
