/**
  @file
  @brief Testing mp_ds2squeeze.sas macro

  <h4> SAS Macros </h4>
  @li mf_getvarlen.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_ds2squeeze.sas

**/

data big;
  length my big $32000;
  do i=1 to 1e4;
    my=repeat('oh my',100);
    big='dawg';
    special=._;
    missn=.;
    missc='';
    output;
  end;
run;

%mp_assertscope(SNAPSHOT)
%mp_ds2squeeze(work.big,outds=work.smaller)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking syscc
)
%mp_assert(
  iftrue=(%mf_getvarlen(work.smaller,missn)=3),
  desc=Check missing numeric is 3
)
%mp_assert(
  iftrue=(%mf_getvarlen(work.smaller,special)=3),
  desc=Check missing special numeric is 3
)
%mp_assert(
  iftrue=(%mf_getvarlen(work.smaller,missc)=1),
  desc=Check missing char is 1
)
