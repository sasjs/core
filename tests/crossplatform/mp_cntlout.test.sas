/**
  @file
  @brief Testing mp_cntlout.sas macro

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_cntlout.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

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

%mp_assertscope(SNAPSHOT)
%mp_cntlout(libcat=perm.testcat,cntlout=work.cntlout)
%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(%mf_nobs(work.cntlout)=10000),
  desc=Checking first hash diff,
  outds=work.test_results
)
