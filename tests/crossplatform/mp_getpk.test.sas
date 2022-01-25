/**
  @file
  @brief Testing mp_getpk.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_getpk.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas

  <h4> Related Macros </h4>
  @li mp_getpk.sas

**/

/* ensure PK arrives in corrrect order */
proc sql;
create table work.example1(
  TX_FROM float format=datetime19.,
  DD_TYPE char(16),
  DD_SOURCE char(2048),
  DD_SHORTDESC char(256),
  constraint pk primary key(tx_from, dd_type,dd_source),
  constraint unq unique(tx_from, dd_type),
  constraint nnn not null(DD_SHORTDESC)
);
%mp_getpk(work,ds=example1,outds=test1)

data _null_;
  set work.test1;
  call symputx('test1',pk_fields);
run;

%mp_assert(
  iftrue=("&test1"="TX_FROM DD_TYPE DD_SOURCE"),
  desc=mp_getpk gets regular PK values in correct order,
  outds=work.test_results
)

/* unique key with NOT NULL captured */
proc sql;
create table work.example2(
  TX_FROM float format=datetime19.,
  DD_TYPE char(16),
  DD_SOURCE char(2048),
  DD_SHORTDESC char(256),
  constraint unq1 unique(tx_from, dd_type),
  constraint unq2 unique(tx_from, dd_type, dd_source),
  constraint nnn not null(tx_from),
  constraint nnnn not null(dd_type)
);
%mp_getpk(work,ds=example2,outds=test2)

data _null_;
  set work.test2;
  call symputx('test2',pk_fields);
run;

%mp_assert(
  iftrue=("&test2"="TX_FROM DD_TYPE"),
  desc=mp_getpk gets unique constraint with NOT NULL in correct order
)

/* unique key without NOT NULL NOT captured */
proc sql;
create table work.example3(
  TX_FROM float format=datetime19.,
  DD_TYPE char(16),
  DD_SOURCE char(2048),
  DD_SHORTDESC char(256),
  constraint unq1 unique(tx_from, dd_type),
  constraint unq2 unique(tx_from, dd_type, dd_source),
  constraint nnn not null(tx_from)
);
%mp_getpk(work,ds=example3,outds=test3)

%mp_assert(
  iftrue=(%mf_nobs(work.test3)=0),
  desc=mp_getpk does not capture unique constraint without NOT NULL,
  outds=work.test_results
)

/* constraint capture at library level is functional - uses first 2 tests */
%mp_getpk(work,outds=test4)

%mp_assertdsobs(work.test4,test=ATLEAST 2)