/**
  @file
  @brief Testing mp_assertcolvals macro

  <h4> SAS Macros </h4>
  @li mp_assertcolvals.sas
  @li mp_assertmodel.sas

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


data work.assert_schema;
  length test_result $5 test_description $256 test_comments $256;
  call missing(test_result,test_description,test_comments);
  stop;
run;
%mp_assertmodel(work.test_results,base=work.assert_schema,
  desc=Checking mp_assertcolvals output schema,outds=work.schema_results)
proc append base=work.test_results data=work.schema_results;
run;
