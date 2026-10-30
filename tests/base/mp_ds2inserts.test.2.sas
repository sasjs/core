/**
  @file
  @brief Testing mp_ds2inserts.sas macro with special missing values

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_ds2inserts.sas

**/

/* numeric cells holding special missings, alongside a plain missing and an
  ordinary value */
data work.spm(keep=id n c);
  id=1; n=._; c='a'; output;
  id=2; n=.A; c='b'; output;
  id=3; n=.;  c='c'; output;
  id=4; n=42; c='d'; output;
run;

filename testref temp;
%mp_ds2inserts(work.spm,outref=testref,schema=work,outds=copy,flavour=SAS)

/* both special missings must reach the statement with their leading period */
%let periodflg=0;
data _null_;
  infile testref end=eof;
  retain found 0;
  input;
  if index(_infile_,'n=._') or index(_infile_,'n=.A') then found+1;
  if eof then call symputx('periodflg',found,'l');
run;
%mp_assert(
  iftrue=(&periodflg=2),
  desc=Checking the period is written for special missings,
  outds=work.test_results
)

/* empty target with the same structure, loaded from the generated inserts */
data work.copy;
  if 0 then set work.spm;
  stop;
run;
proc sql;
%inc testref;
quit;

/* the inserts must actually load - an invalid statement leaves the target
  empty, and the compare below would then run in syntax-check mode */
%let copyobs=0;
data _null_;
  if 0 then set work.copy nobs=nn;
  call symputx('copyobs',nn,'l');
  stop;
run;
%mp_assert(
  iftrue=(&copyobs=4),
  desc=Checking all four rows were inserted,
  outds=work.test_results
)

/* the loaded values must match the source, special missings included - a plain
  ne catches ._ vs . and .A vs .B, as special missings compare as values */
proc sort data=work.spm out=work.spm_s;
  by id;
run;
proc sort data=work.copy out=work.copy_s;
  by id;
run;
%let valfail=0;
data _null_;
  merge work.spm_s(in=a rename=(n=n_exp c=c_exp)) work.copy_s(in=b) end=eof;
  by id;
  retain bad 0;
  if not (a and b) then bad+1;
  else if n ne n_exp or c ne c_exp then bad+1;
  if eof then call symputx('valfail',bad,'l');
run;
%mp_assert(
  iftrue=(&valfail=0),
  desc=Checking inserts round trip special missing values,
  outds=work.test_results
)
