/**
  @file
  @brief Testing mp_getdbml macro

  <h4> SAS Macros </h4>
  @li mf_mkdir.sas
  @li mp_getdbml.sas
  @li mp_assert.sas

**/

%let root=%sysfunc(pathname(work))/dbml;
%mf_mkdir(&root)
libname mcdb "&root";

data mcdb.customers;
  length cust_id 8 cust_name $20;
  cust_id=1; cust_name='one'; output;
run;

proc sql;
  alter table mcdb.customers
    add constraint pk_customers primary key (cust_id);
quit;

filename dbmlref "&root/model.dbml";

%mp_getdbml(liblist=mcdb,outref=dbmlref)

%let has_table=0;
%let has_name=0;
%let has_project=0;

data _null_;
  infile dbmlref truncover end=last;
  input;
  if index(_infile_,'Table ') > 0 then call symputx('has_table',1,'g');
  if find(upcase(_infile_),'CUSTOMERS') then call symputx('has_name',1,'g');
  if index(_infile_,'Project ') > 0 then call symputx('has_project',1,'g');
run;

%mp_assert(
  iftrue=(&has_project=1),
  desc=Checking that the dbml project header is written,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&has_table=1),
  desc=Checking that a table block is written for the library member,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&has_name=1),
  desc=Checking that the table name appears in the dbml,
  outds=work.test_results
)
