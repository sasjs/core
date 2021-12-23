/**
  @file
  @brief Testing mp_makedata.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_makedata.sas
  @li mp_assert.sas

**/

/**
  * Test 1 - Regular makedata call
  */

proc sql;
create table work.example(
  TX_FROM float format=datetime19.,
  DD_TYPE char(16),
  DD_SOURCE char(2048),
  DD_SHORTDESC char(256),
  constraint pk primary key(tx_from, dd_type,dd_source),
  constraint nnn not null(DD_SHORTDESC)
);
%mp_makedata(work.example,obs=500)

%mp_assert(
  iftrue=("%mf_nobs(work.example)"="500"),
  desc=Check that 500 rows were created,
  outds=work.test_results
)

data _null_;
  set work.example;
  call symputx('lenvar',length(dd_source));
  stop;
run;
%mp_assert(
  iftrue=("&lenvar"="2048"),
  desc=Check that entire length of variable is populated,
  outds=work.test_results
)


proc sql;
create table work.example2(
  TX_FROM float format=datetime19.,
  DD_TYPE char(16),
  DD_SOURCE char(2048),
  DD_SHORTDESC char(256),
  some_num num
);
%mp_makedata(work.example2)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Ensure tables without keys still generate,
  outds=work.test_results
)