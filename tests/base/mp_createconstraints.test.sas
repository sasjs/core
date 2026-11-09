/**
  @file
  @brief Testing mp_createconstraints macro

  <h4> SAS Macros </h4>
  @li mp_createconstraints.sas
  @li mp_assert.sas

**/

data work.constraints;
  length libref $8 table_name $32 constraint_name $32 constraint_type $12
    column_name $32;
  libref='WORK'; table_name='CLASSC'; constraint_name='PK_CLASSC';
  constraint_type='PRIMARY'; column_name='id'; output;
  libref='WORK'; table_name='CLASSC'; constraint_name='PK_CLASSC';
  constraint_type='PRIMARY'; column_name='name'; output;
run;

%mp_createconstraints(inds=work.constraints,outds=work.cc_out,execute=NO)

proc sql noprint;
  select count(*) into: n_stmt from work.cc_out;
  select count(*) into: n_pk from work.cc_out
    where index(create_statement,'PRIMARY KEY')>0;
  select count(*) into: n_cols from work.cc_out
    where index(create_statement,'id')>0 or index(create_statement,'name')>0;
quit;

%mp_assert(
  iftrue=(&n_stmt=2),
  desc=Checking that one create statement is produced per column,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_pk=1),
  desc=Checking that a PRIMARY constraint becomes a PRIMARY KEY clause,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_cols=2),
  desc=Checking that the column name is carried into each statement,
  outds=work.test_results
)

/* execute=YES must run the generated sql cleanly */
data work.classt;
  length id 8 name $10;
  id=1; name='one'; output;
  id=2; name='two'; output;
run;

data work.constraints2;
  length libref $8 table_name $32 constraint_name $32 constraint_type $12
    column_name $32;
  libref='WORK'; table_name='CLASST'; constraint_name='PK_CLASST';
  constraint_type='PRIMARY'; column_name='id';
run;

%mp_createconstraints(inds=work.constraints2,outds=work.cc_out2,execute=YES)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking that execute=YES runs the generated statements cleanly,
  outds=work.test_results
)
