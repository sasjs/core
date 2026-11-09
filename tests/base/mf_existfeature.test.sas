/**
  @file
  @brief Testing mf_existfeature macro

  <h4> SAS Macros </h4>
  @li mf_existfeature.sas
  @li mf_getplatform.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* Viya (4.x) and CAS (5.x) answer 0 for these two features - see the macro */
%if %substr(&sysver,1,1)=4 or %substr(&sysver,1,1)=5 %then %do;
  %let expect_colcons=0;
  %let expect_memtype=0;
%end;
%else %do;
  %let expect_colcons=1;
  %let expect_memtype=1;
%end;

%mp_assertscope(SNAPSHOT)
%put scope check:%mf_existfeature(COLCONSTRAINTS) on %mf_getplatform();
%mp_assertscope(COMPARE,
  desc=Checking that mf_existfeature does not leak scope,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existfeature(COLCONSTRAINTS)=&expect_colcons),
  desc=Checking that column constraints are detected on SAS 9.4 and above,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existfeature(DBMS_MEMTYPE)=&expect_memtype),
  desc=Checking that dbms_memtype is detected on SAS 9.4 and above,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existfeature(NOSUCHFEATURE)=-1),
  desc=Checking that an unknown feature returns -1,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%index(01,%mf_existfeature(PROCLUA))>0),
  desc=Checking that PROCLUA answers 0 or 1 according to the environment,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%index(01,%mf_existfeature(EXPORTXLS))>0),
  desc=Checking that EXPORTXLS answers 0 or 1 according to the environment,
  outds=work.test_results
)
