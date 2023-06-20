/**
  @file
  @brief Testing mp_aligndecimal macro
  @details Creates an aligned variable and checks the number of leading blanks

  <h4> SAS Macros </h4>
  @li mp_aligndecimal.sas
  @li mp_assertcolvals.sas
  @li mp_assertscope.sas

**/



/* target values */
data work.checkds;
  do checkval='   0.56',' 123.45',' 123.4 ','   1.2 ','   0';
    output;
  end;
run;

/* raw values */
data work.rawds;
  set work.checkds;
  tgtvar=cats(checkval);
  drop checkval;
run;
%mp_assertcolvals(work.rawds.tgtvar,
  checkvals=work.checkds.checkval,
  desc=No values match (ready to align),
  test=NOVAL
)

/* aligned values */
%mp_assertscope(SNAPSHOT)
data work.finalds;
  set work.rawds;
  %mp_aligndecimal(tgtvar,width=4)
run;
%mp_assertscope(COMPARE)

%mp_assertcolvals(work.finalds.tgtvar,
  checkvals=work.checkds.checkval,
  desc=All values match (aligned),
  test=ALLVALS
)
