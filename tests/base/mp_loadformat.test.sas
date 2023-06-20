/**
  @file
  @brief Testing mp_loadformat.sas macro
  @details first test regular formats, then informats

  <h4> SAS Macros </h4>
  @li mddl_dc_difftable.sas
  @li mp_aligndecimal.sas
  @li mp_loadformat.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* prep format catalog */
libname perm (work);

%mddl_dc_difftable(libds=perm.audit)

/* set up regular formats */
data work.loadfmts;
  /* matching start / end lengths (to baseds) are important */
  length fmtname $32 start end $10000;
  eexcl='Y';
  type='N';
  do i=1 to 100;
    fmtname=cats('SASJS_',i,'X');
    do j=1 to 100;
      start=cats(j);
      end=cats(j+1);
      %mp_aligndecimal(start,width=16)
      %mp_aligndecimal(end,width=16)
      label= cats('Numeric Format ',start);
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
    %mp_aligndecimal(start,width=16)
    %mp_aligndecimal(end,width=16)
    label='newval'!!cats(_N_);
  end;
  else stop;
run;

/* load the above */
%mp_assertscope(SNAPSHOT)
%mp_loadformat(perm.testcat
  ,work.stagedata
  ,loadtarget=YES
  ,auditlibds=perm.audit
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
%mp_assert(
  iftrue=(%mf_nobs(perm.audit)=7329),
  desc=Test 1 - audit table updated,
  outds=work.test_results
)
data work.difftest;
  set perm.audit;
  where is_diff=1;
run;
%mp_assert(
  iftrue=(%mf_nobs(work.difftest)>0),
  desc=Test 1 - diffs were found,
  outds=work.test_results
)

/* set up a mix of formats */
data work.loadfmts2;
  length fmtname $32 start end $10000;
  eexcl='Y';
  type='J';
  do i=1 to 3;
    fmtname=cats('SASJS_CI_',i,'X');
    do j=1 to 4;
      start=cats(j);
      end=start;
      label= cats('Char INFORMAT ',start);
      output;
    end;
  end;
  type='I';
  do i=1 to 3;
    fmtname=cats('SASJS_NI_',i,'X');
    do j=1 to 4;
      start=cats(j);
      end=cats(j+1);
      %mp_aligndecimal(start,width=16)
      %mp_aligndecimal(end,width=16)
      label= cats(ranuni(0));
      output;
    end;
  end;
  type='N';
  do i=1 to 3;
    fmtname=cats('SASJS_NF_',i,'X');
    do j=1 to 4;
      start=cats(j);
      end=cats(j+1);
      %mp_aligndecimal(start,width=16)
      %mp_aligndecimal(end,width=16)
      label= cats('Numeric Format ',start);
      output;
    end;
  end;
  type='C';
  do i=1 to 3;
    fmtname=cats('SASJS_CF_',i,'X');
    do j=1 to 4;
      start=cats(j);
      end=start;
      label= cats('Char Format ',start);
      output;
    end;
  end;
  drop i j;
run;
proc format cntlin=work.loadfmts2 library=perm.testcat2;
run;

/* make some test data */
data work.stagedata2;
  set work.loadfmts2;
  where type in ('I','J');
  eexcl='Y';
  if type='I' then do;
    i+1;
    if i<3 then deleteme='Yes';
    else if i<7 then label= cats(ranuni(0)*100);
    else if i<12 then do;
      /* new values */
      z=ranuni(0)*1000000;
      start=cats(z);
      end=cats(z+1);
      %mp_aligndecimal(start,width=16)
      %mp_aligndecimal(end,width=16)
      label= cats(ranuni(0)*100);
    end;
    if i<12 then output;
  end;
  else do;
    j+1;
    if j<3 then deleteme='Yes';
    else if j<7 then label= cats(ranuni(0)*100);
    else if j<12 then do;
      start= cats("NEWVAL",start);
      end=start;
      label= "NEWVAL "||cats(ranuni(0)*100);
    end;
    if j<12 then output;
  end;

run;

%mp_loadformat(perm.testcat2
  ,work.stagedata2
  ,loadtarget=YES
  ,auditlibds=perm.audit
  ,locklibds=0
  ,delete_col=deleteme
  ,outds_add=add_test2
  ,outds_del=del_test2
  ,outds_mod=mod_test2
  ,mdebug=1
)

%mp_assert(
  iftrue=(%mf_nobs(del_test2)=4),
  desc=Test 2 - delete obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(mod_test2)=8),
  desc=Test 2 - mod obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(add_test2)=10),
  desc=Test 2 - add obs,
  outds=work.test_results
)
