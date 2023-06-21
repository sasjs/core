/**
  @file
  @brief Testing mp_loadformat.sas macro for multilabel formats
  @details Multilabel records can be complete duplicates!!  Also, the order is
  important.

  The provided formats create a table as follows:


|TYPE:$1.|FMTNAME:$32.|START:$10000.|END:$10000.|LABEL:$32767.|MIN:best.|MAX:best.|DEFAULT:best.|LENGTH:best.|FUZZ:best.|PREFIX:$2.|MULT:best.|FILL:$1.|NOEDIT:best.|SEXCL:$1.|EEXCL:$1.|HLO:$13.|DECSEP:$1.|DIG3SEP:$1.|DATATYPE:$8.|LANGUAGE:$8.|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|`C `|`GENDERML `|` `|` `|`Total people `|`1 `|`40 `|`12 `|`12 `|`0 `|` `|`0 `|` `|`0 `|`N `|`N `|`M `|` `|` `|` `|` `|
|`C `|`GENDERML `|`1 `|`1 `|`Male `|`1 `|`40 `|`12 `|`12 `|`0 `|` `|`0 `|` `|`0 `|`N `|`N `|`M `|` `|` `|` `|` `|
|`C `|`GENDERML `|`1 `|`1 `|`Total people `|`1 `|`40 `|`12 `|`12 `|`0 `|` `|`0 `|` `|`0 `|`N `|`N `|`M `|` `|` `|` `|` `|
|`C `|`GENDERML `|`2 `|`2 `|`Female `|`1 `|`40 `|`12 `|`12 `|`0 `|` `|`0 `|` `|`0 `|`N `|`N `|`M `|` `|` `|` `|` `|
|`C `|`GENDERML `|`2 `|`2 `|`Female `|`1 `|`40 `|`12 `|`12 `|`0 `|` `|`0 `|` `|`0 `|`N `|`N `|`M `|` `|` `|` `|` `|
|`C `|`GENDERML `|`2 `|`2 `|`Thormale `|`1 `|`40 `|`12 `|`12 `|`0 `|` `|`0 `|` `|`0 `|`N `|`N `|`M `|` `|` `|` `|` `|
|`C `|`GENDERML `|`2 `|`2 `|`Total people `|`1 `|`40 `|`12 `|`12 `|`0 `|` `|`0 `|` `|`0 `|`N `|`N `|`M `|` `|` `|` `|` `|
|`N `|`AGEMLA `|`1 `|`4 `|`Preschool `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLA `|`1 `|`18 `|`Children `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLA `|`19 `|`120 `|`Adults `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLB `|`1 `|`4 `|`Preschool `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLB `|`1 `|`18 `|`Children `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLB `|`19 `|`120 `|`Adults `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLC `|`1 `|`18 `|`Children `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLC `|`1 `|`4 `|`Preschool `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|
|`N `|`AGEMLC `|`19 `|`120 `|`Adults `|`1 `|`40 `|`9 `|`9 `|`1E-12 `|` `|`0 `|` `|`0 `|`N `|`N `|`SM `|` `|` `|` `|` `|


  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_cntlout.sas
  @li mp_loadformat.sas
  @li mp_assert.sas
  @li mp_assertdsobs.sas

**/

/* prep format catalog */
libname perm (work);

/* create some multilable formats */
%let cat1=perm.test1;
proc format library=&cat1;
  value $genderml (multilabel notsorted)
    '1'='Male'
    '2'='Female'
    '2'='Female'
    '2'='Farmale'
    '1','2',' '='Total people';
  value agemla (multilabel)
    1-4='Preschool'
    1-18='Children'
    19-120='Adults';
  value agemlb (multilabel)
    19-120='Adults'
    1-18='Children'
    1-4='Preschool';
  value agemlc (multilabel notsorted)
    19-120='Adults'
    1-18='Children'
    1-4='Preschool';
run;

%mp_cntlout(libcat=&cat1,cntlout=work.cntlout1)
%mp_assertdsobs(work.cntlout1,
  desc=Has 16 records,
  test=EQUALS 16
)

data work.stagedata3;
  set work.cntlout1;
  if fmtname='AGEMLA' and label ne 'Preschool' then deleteme='Yes';
  if fmtname='AGEMLB' and label = 'Preschool' then label='Kids';
  if fmtname='GENDERML' and label='Farmale' then output;
  output;
run;


%mp_loadformat(&cat1
  ,work.stagedata3
  ,loadtarget=YES
  ,auditlibds=perm.audit
  ,locklibds=0
  ,delete_col=deleteme
  ,outds_add=add_test1
  ,outds_del=del_test1
  ,outds_mod=mod_test1
  ,mdebug=1
)

%mp_assert(
  iftrue=(%mf_nobs(del_test1)=2),
  desc=Test 1 - deleted obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(mod_test1)=4),
  desc=Test 1 - mod obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(add_test1)=1),
  desc=Test 1 - add obs,
  outds=work.test_results
)

/* now check the order of the notsorted format */
%mp_cntlout(libcat=&cat1,cntlout=work.cntlout2)

%let check1=0;
%let check2=0;
data test;
  set work.cntlout2;
  where fmtname='GENDERML';
  if _n_=4 and label='Farmale' then call symputx('check1',1);
  if _n_=5 and label='Farmale' then call symputx('check2',1);
run;
%mp_assert(
  iftrue=(&check1=1 and &check2=1),
  desc=Ensuring Farmale values retain their order,
  outds=work.test_results
)