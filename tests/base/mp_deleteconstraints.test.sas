/**
  @file
  @brief Testing mp_deleteconstraints macro

  <h4> SAS Macros </h4>
  @li mp_deleteconstraints.sas
  @li mp_assert.sas

**/

data work.constraints;
  length libref $8 table_name $32 constraint_name $32 constraint_type $12
    column_name $32;
  libref='WORK'; table_name='CLASST'; constraint_name='PK_CLASST';
  constraint_type='PRIMARY'; column_name='id'; output;
  libref='WORK'; table_name='CLASST'; constraint_name='PK_CLASST';
  constraint_type='PRIMARY'; column_name='name'; output;
run;

%mp_deleteconstraints(inds=work.constraints,outds=work.dc_out,execute=NO)

proc sql noprint;
  select count(*) into: n_stmt from work.dc_out;
  select count(*) into: n_drop from work.dc_out
    where index(drop_statement,'drop constraint PK_CLASST')>0;
quit;

%mp_assert(
  iftrue=(&n_stmt=1),
  desc=Checking that one drop statement is produced per constraint,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_drop=1),
  desc=Checking that the drop statement names the constraint,
  outds=work.test_results
)
