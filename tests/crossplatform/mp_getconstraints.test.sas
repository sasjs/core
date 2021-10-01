/**
  @file
  @brief Testing mp_getconstraints.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_getconstraints.sas
  @li mp_assert.sas

**/

proc sql;
create table work.example(
  TX_FROM float format=datetime19.,
  DD_TYPE char(16),
  DD_SOURCE char(2048),
  DD_SHORTDESC char(256),
  constraint pk primary key(tx_from, dd_type,dd_source),
  constraint unq unique(tx_from, dd_type),
  constraint nnn not null(DD_SHORTDESC)
);

%mp_getconstraints(lib=work,ds=example,outds=work.constraints)

%mp_assert(
  iftrue=(%mf_nobs(work.constraints)=6),
  desc=Output table work.constraints created with correct number of records,
  outds=work.test_results
)