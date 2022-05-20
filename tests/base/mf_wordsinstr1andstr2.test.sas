/**
  @file
  @brief Testing mf_wordsinstr1andstr2 macro

  <h4> SAS Macros </h4>
  @li mf_wordsinstr1andstr2.sas
  @li mp_assert.sas

**/

%let x=%mf_wordsinstr1andstr2(str1=xx DOLLAR x $CHAR xxx W MONNAME
  ,str2=DOLLAR $CHAR W MONNAME xxxxxx
);
%mp_assert(
  iftrue=(
    "&x"="DOLLAR $CHAR W MONNAME"
  ),
  desc=Checking basic string,
  outds=work.test_results
)
