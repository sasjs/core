/**
  @file
  @brief Testing mp_loadformat.sas macro

  <h4> SAS Macros </h4>
  @li mp_loadformat.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* prep format catalog */
libname perm (work);

data work.loadfmts;
  length fmtname $32;
  eexcl='Y';
  type='N';
  do i=1 to 100;
    fmtname=cats('SASJS_',i,'X');
    do j=1 to 100;
      start=cats(j);
      end=cats(j+1);
      label= cats('Dummy ',start);
      output;
    end;
  end;
run;
proc format cntlin=work.loadfmts library=perm.testcat;
run;

/* make some test data */
data work.stagedata;
  set work.loadfmts;
  type='N';
  eexcl='Y';
  if _n_<150 then deleteme='Yes';
  else if _n_<250 then label='mod'!!cats(_n_);
  else if _n_<350 then do;
    start=cats(_n_);
    end=cats(_n_+1);
    label='newval'!!cats(_N_);
  end;
  else stop;
run;

/* load the above */
%mp_assertscope(SNAPSHOT)
%mp_loadformat(perm.testcat
  ,work.stagedata
  ,loadtarget=YES
  ,auditlibds=0
  ,locklibds=0
  ,delete_col=deleteme
  ,outds_add=add_test1
  ,outds_del=del_test1
  ,outds_mod=mod_test1
  ,mdebug=1
)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(%mf_nobs(del_test1)=149),
  desc=Test 1 - delete obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(add_test1)=100),
  desc=Test 1 - add obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(mod_test1)=100),
  desc=Test 1 - mod obs,
  outds=work.test_results
)