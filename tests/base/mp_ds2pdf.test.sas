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
filename pdf4 temp;
filename pdf5 temp;
filename pdf6 temp;

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

/* the total form of the page number */
%mp_ds2pdf(sashelp.class, outref=pdf4, pagenum=PAGEOF)

/* and the same report with no numbering, so the two can be compared */
%mp_ds2pdf(sashelp.class, outref=pdf5, pagenum=NO)

/* the report must not depend on the caller's ODS escape character: with one
  set, the same call has to produce the same file as pdf1 */
ods escapechar='^';

%mp_ds2pdf(sashelp.class, outref=pdf6
  ,title=Class listing
  ,footnote=Core test)

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

/* the byte size is read with finfo() rather than by counting records, so a
  padded record length cannot stand in for the file size */
data _null_;
  fid=fopen('pdf1');
  s1=finfo(fid,'File Size (bytes)');
  rc=fclose(fid);
  fid=fopen('pdf2');
  s2=finfo(fid,'File Size (bytes)');
  rc=fclose(fid);
  fid=fopen('pdf4');
  s4=finfo(fid,'File Size (bytes)');
  rc=fclose(fid);
  fid=fopen('pdf5');
  s5=finfo(fid,'File Size (bytes)');
  rc=fclose(fid);
  fid=fopen('pdf6');
  s6=finfo(fid,'File Size (bytes)');
  rc=fclose(fid);
  call symputx('size1',s1,'l');
  call symputx('size2',s2,'l');
  call symputx('size4',s4,'l');
  call symputx('size5',s5,'l');
  call symputx('size6',s6,'l');
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
  iftrue=(&size2 < &size1),
  desc=Checking maxobs reduces the report,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&size4 > &size5),
  desc=Checking the page total is written to the page,
  outds=work.test_results
)
%mp_assert(
  iftrue=(&size6 = &size1),
  desc=Checking a caller escape character does not change the report,
  outds=work.test_results
)
