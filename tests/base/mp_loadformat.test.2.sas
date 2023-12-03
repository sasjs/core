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
  @li mp_getformats.sas
  @li mp_ds2md.sas


**/

/* prep format catalog */
libname perm (work);

/* create some multilabel formats */
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
    0-1='Preschool'
    1-2='Preschool'
    2-3='Preschool'
    1-4='Preschool';
  value agemlc (multilabel notsorted)
    19-120='Adults'
    1-18='Children'
    1-4='Preschool';
run;

%mp_cntlout(libcat=&cat1,cntlout=work.cntlout1)
%mp_assertdsobs(work.cntlout1,
  desc=Has 19 records,
  test=EQUALS 19
)

data work.stagedata3;
  set work.cntlout1;
  if fmtname='AGEMLA' and label ne 'Preschool' then deleteme='Yes';
  if fmtname='AGEMLB' and label = 'Preschool' then label='Kids';
  if fmtname='GENDERML' and label='Farmale' then do;
    output;
    fmtrow=101; output;
  end;
  else output;
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
%let check3=0;
data test;
  set work.cntlout2;
  where fmtname='GENDERML';
  putlog fmtrow= label=;
  if _n_=4 and label='Farmale' then call symputx('check1',1);
  if _n_=5 and label ne 'Farmale' then call symputx('check2',1);
  if _n_=8 and label = 'Farmale' then call symputx('check3',1);
run;
%mp_assert(
  iftrue=(&check1=1 and &check2=1 and &check3=1),
  desc=Ensuring Farmale values retain their order,
  outds=work.test_results
)

/**
  * completely delete a format and make sure it is removed
  */

/* first, make sure these three formats exist */
options insert=(fmtsearch=(&cat1));
%mp_getformats(fmtlist=AGEMLA AGEMLB AGEMLC $GENDERML,outsummary=work.fmtdels)

%let fmtlist=NONE;
proc sql;
select distinct cats(fmtname) into: fmtlist separated by ' ' from work.fmtdels;

%mp_assert(
  iftrue=(%mf_nobs(fmtdels)=4),
  desc=Deletion test 1 - ensure formats exist for deletion (&fmtlist found),
  outds=work.test_results
)

/* deltest1 - deleting every record */
%mp_cntlout(libcat=&cat1,cntlout=work.cntloutdel1)
data work.stagedatadel1;
  set work.cntloutdel1;
  if fmtname='AGEMLA';
  deleteme='Yes';
run;
%mp_loadformat(&cat1
  ,work.stagedatadel1
  ,loadtarget=YES
  ,auditlibds=perm.audit
  ,locklibds=0
  ,delete_col=deleteme
  ,outds_add=add_testdel1
  ,outds_del=del_testdel1
  ,outds_mod=mod_testdel1
  ,mdebug=1
)
%mp_getformats(fmtlist=AGEMLA,outsummary=work.fmtdel1)
%mp_assert(
  iftrue=(%mf_nobs(fmtdel1)=0),
  desc=Deletion test 1 - ensure AGEMLA format was fully deleted,
  outds=work.test_results
)

/* deltest2 - deleting every record except 1 */
data work.stagedatadel2;
  set work.cntloutdel1;
  if fmtname='AGEMLB';
  x+1;
  if x>1 then deleteme='Yes';
run;
%mp_loadformat(&cat1
  ,work.stagedatadel2
  ,loadtarget=YES
  ,auditlibds=perm.audit
  ,locklibds=0
  ,delete_col=deleteme
  ,outds_add=add_testdel2
  ,outds_del=del_testdel2
  ,outds_mod=mod_testdel2
  ,mdebug=1
)
%mp_getformats(fmtlist=AGEMLB,outsummary=work.fmtdel2)
%mp_assert(
  iftrue=(%mf_nobs(fmtdel2)=1),
  desc=Deletion test 2 - ensure AGEMLB format was not fully deleted,
  outds=work.test_results
)


/* deltest3 - deleting every record, and adding a new one */
data work.stagedatadel3;
  set work.cntloutdel1;
  if fmtname='GENDERML';
  deleteme='Yes';
run;
data work.stagedatadel3;
  set work.stagedatadel3 end=last;
  output;
  if last then do;
    deleteme='No';
    /* must be a new fmtrow (key value) if adding new row in same load! */
    fmtrow=1000;
    start='Mail';
    end='Mail';
    output;
  end;
run;

%mp_loadformat(&cat1
  ,work.stagedatadel3
  ,loadtarget=YES
  ,auditlibds=perm.audit
  ,locklibds=0
  ,delete_col=deleteme
  ,outds_add=add_testdel2
  ,outds_del=del_testdel2
  ,outds_mod=mod_testdel2
  ,mdebug=1
)
%mp_getformats(fmtlist=$GENDERML,outsummary=work.fmtdel3)
%mp_assert(
  iftrue=(%mf_nobs(fmtdel3)=1),
  desc=Deletion test 3 - ensure GENDERML format was not fully deleted,
  outds=work.test_results
)

%mp_ds2md(work.fmtdel3)