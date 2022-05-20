/**
  @file
  @brief Testing mp_getconstraints.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_getconstraints.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/


%macro conditional();

%if %sysfunc(exist(sashelp.vcncolu,view))=1 %then %do;
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
  %mp_assertscope(SNAPSHOT)
  %mp_getconstraints(lib=work,ds=example,outds=work.constraints)
  %mp_assertscope(COMPARE)

  %mp_assert(
    iftrue=(%mf_nobs(work.constraints)=6),
    desc=Output table work.constraints created with correct number of records,
    outds=work.test_results
  )
%end;
%else %do;
  proc sql;
  create table work.example(
    TX_FROM float format=datetime19.,
    DD_TYPE char(16),
    DD_SOURCE char(2048),
    DD_SHORTDESC char(256)
  );
  %mp_assertscope(SNAPSHOT)
  %mp_getconstraints(lib=work,ds=example,outds=work.constraints)
  %mp_assertscope(COMPARE)

  %mp_assert(
    iftrue=(%mf_nobs(work.constraints)=0),
    desc=Empty table created as constraints not supported,
    outds=work.test_results
  )
%end;
%mend conditional;

%conditional()
