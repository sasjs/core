/**
  @file
  @brief Testing mp_ds2pdf.sas macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_ds2pdf.sas

**/

filename pdf1 temp;
filename pdf2 temp;
filename pdf3 temp;

%mp_ds2pdf(sashelp.class, outref=pdf1
  ,title=Class listing
  ,footnote=Core test)

%mp_ds2pdf(sashelp.class, outref=pdf2, maxobs=3
  ,title=Class listing
  ,footnote=Core test)

/* PROC PRINT requires the input sorted by the BY variables */
proc sort data=sashelp.class out=work.classsex;
  by SEX;
run;

%mp_ds2pdf(work.classsex, outref=pdf3, by=SEX
  ,title=By group listing)

%let titleopt=%sysfunc(getoption(title));

data _null_;
  infile pdf1 recfm=f lrecl=8 obs=1;
  length sig $8;
  input sig $8.;
  call symputx('sigfull',substr(sig,1,5),'l');
run;

data _null_;
  infile pdf3 recfm=f lrecl=8 obs=1;
  length sig $8;
  input sig $8.;
  call symputx('sigby',substr(sig,1,5),'l');
run;

data _null_;
  infile pdf1 recfm=f lrecl=32767 end=eof;
  retain sz 0;
  input;
  sz+length(_infile_);
  if eof then call symputx('sizefull',sz,'l');
run;

data _null_;
  infile pdf2 recfm=f lrecl=32767 end=eof;
  retain sz 0;
  input;
  sz+length(_infile_);
  if eof then call symputx('sizecapped',sz,'l');
run;

/* the signature is checked in a data step so the percent sign in the PDF
  magic number is not read as a macro call by the linter */
data _null_;
  length sigfull sigby $5;
  sigfull=symget('sigfull');
  sigby=symget('sigby');
  call symputx('issigfull'
    ,ifc(sigfull='%PDF-','Y','N'),'l');
  call symputx('issigby'
    ,ifc(sigby='%PDF-','Y','N'),'l');
run;

%mp_assert(
  iftrue=("&issigfull"="Y"),
  desc=Checking the file starts with a PDF signature,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&issigby"="Y"),
  desc=Checking a by group report is also a PDF,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&sizecapped < &sizefull),
  desc=Checking maxobs reduces the report,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&titleopt"=""),
  desc=Checking the title is cleared after the report,
  outds=work.test_results
)
