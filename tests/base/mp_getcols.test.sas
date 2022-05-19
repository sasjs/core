/**
  @file
  @brief Testing mp_getcols macro

  <h4> SAS Macros </h4>
  @li mp_getcols.sas
  @li mp_assertcols.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas

**/


/* valid filter */
%mp_getcols(sashelp.airline,outds=work.info)


%mp_assertdsobs(work.info,
  desc=Has 3 records,
  test=EQUALS 3,
  outds=work.test_results
)

data work.check;
  length val $10;
  do val='NUMERIC','DATE','CHARACTER';
    output;
  end;
run;
%mp_assertcolvals(work.info.ddtype,
  checkvals=work.check.val,
  desc=All values have a match,
  test=ALLVALS
)

%mp_assertcols(work.info,
  cols=name type length varnum format label ddtype fmtname,
  test=ALL,
  desc=check all columns exist
)