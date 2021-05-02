/**
  @file
  @brief Testing mp_assertcolvals macro

  <h4> SAS Macros </h4>
  @li mp_assertcolvals.sas

**/


data work.checkds;
  do checkval='Jane','James','Jill';
    output;
  end;
run;
%mp_assertcolvals(sashelp.class.name,
  checkvals=work.checkds.checkval,
  desc=At least one value has a match,
  test=ANYVAL
)

data work.check;
  do val='M','F';
    output;
  end;
run;
%mp_assertcolvals(sashelp.class.sex,
  checkvals=work.check.val,
  desc=All values have a match,
  test=ALLVALS
)


%webout(OPEN)
%webout(OBJ, TEST_RESULTS)
%webout(CLOSE)