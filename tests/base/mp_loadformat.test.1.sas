/**
  @file
  @brief Testing mp_loadformat.sas macro
  @details first test regular formats, then informats

  <h4> SAS Macros </h4>
  @li mddl_dc_difftable.sas
  @li mp_aligndecimal.sas
  @li mp_cntlout.sas
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
  do i=1 to 10;
    fmtname=cats('SASJS_',put(i,z4.),'X');
    do j=1 to 20;
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

/*
  use actual format data as test baseline, as proc format adds attributes eg
  min/max etc
*/
%mp_cntlout(libcat=perm.testcat,cntlout=work.loadfmts2)

/* make some test data */
data work.stagedata;
  set work.loadfmts2 end=lastobs;
  by type fmtname;

  if lastobs then do;
    output;
    fmtname='NEWFMT'!!cats(_n_,'x'); /* 1 new record */
    start=cats(_n_);
    end=cats(_n_+1);
    %mp_aligndecimal(start,width=16)
    %mp_aligndecimal(end,width=16)
    label='newval'!!cats(_N_,'X');
    output;
    stop;
  end;
  else if last.fmtname then deleteme='Yes'; /* 9 deletions */
  else if first.fmtname then label='modified '!!cats(_n_); /* 10 changes */

  output;
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
  iftrue=(%mf_nobs(del_test1)=9),
  desc=Test 1 - delete obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(add_test1)=1),
  desc=Test 1 - add obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(mod_test1)=10),
  desc=Test 1 - mod obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(perm.audit)=440),
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
data work.loadfmts3;
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
proc format cntlin=work.loadfmts3 library=perm.testcat3;
run;
%mp_cntlout(libcat=perm.testcat3,cntlout=work.loadfmts4)

/* make some test data */
data work.stagedata3;
  set work.loadfmts4;
  where type in ('I','J');
  by type fmtname notsorted;
  if type='I' then do;
    if last.fmtname then do;
      deleteme='Yes'; /* 3 deletions */
      output;
    end;
    else if fmtrow le 3 then do; /* 9 changed values */
      z=ranuni(0)*1000000;
      start=cats(z);
      end=cats(z+1);
      %mp_aligndecimal(start,width=16)
      %mp_aligndecimal(end,width=16)
      output;
    end;
  end;
  else do;
    if last.fmtname then do;
      output; /* 6 new records */
      x=_n_;
      x+1;start=cats("mod",x);end=start;label='newlabel1';output;
      x+1;start=cats("mod",x);end=start;label='newlabel2';output;
    end;
    else if fmtrow le 3 then do; /* 9 more changed values */
      start= cats("mod",_n_);
      end=start;
      label= "mod "||cats(ranuni(0)*100);
      output;
    end;
  end;
run;

%mp_loadformat(perm.testcat3
  ,work.stagedata3
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
  iftrue=(%mf_nobs(del_test2)=3),
  desc=Test 2 - delete obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(mod_test2)=18),
  desc=Test 2 - mod obs,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(add_test2)=6),
  desc=Test 2 - add obs,
  outds=work.test_results
)

