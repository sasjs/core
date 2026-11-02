/**
  @file
  @brief Testing mp_streamfile.sas macro
  @details This is tricky to test as it streams to webout.  For now just
  check the compilation, and for macro leakage.  The PDF case streams to a
  temporary fileref instead, so the bytes and the headers can both be
  inspected without touching the response.

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mp_ds2pdf.sas
  @li mp_streamfile.sas

**/

%mp_assertscope(SNAPSHOT)

%mp_streamfile(iftrue=(1=0)
  ,contenttype=csv,inloc=/some/where.txt
  ,outname=myfile.txt
)

%mp_assertscope(COMPARE)

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking the failure condition,
  outds=work.test_results
)

/* a real PDF, streamed to a temp fileref: the same call a caller would make
  for a download, without writing to the response */
filename pdfsrc temp;
filename pdfdst temp;

%mp_ds2pdf(sashelp.class, outref=pdfsrc, title=Streamed)

/* mfs_httpheader writes to this file when it is set, so the headers of the
  SASjs Server branch can be read back.  The redirect is left in place - no
  later test in this program uses mfs_httpheader. */
%let hdrpath=%sysfunc(pathname(work))/pdfheaders.txt;
%let _sasjs_webout_headers=&hdrpath;

%mp_streamfile(contenttype=PDF,inref=pdfsrc,outref=pdfdst
  ,outname=report.pdf)

data _null_;
  length verdict $6 hdrexp $6;
  fid=fopen('pdfsrc');
  srcsz=finfo(fid,'File Size (bytes)');
  rc=fclose(fid);
  fid=fopen('pdfdst');
  dstsz=finfo(fid,'File Size (bytes)');
  rc=fclose(fid);
  call symputx('srcsize',srcsz,'l');
  call symputx('dstsize',dstsz,'l');

  /* only the SASjs Server branch writes headers through mfs_httpheader */
  verdict='NA';
  if fileexist("&hdrpath") then do;
    infile "&hdrpath" truncover end=eof;
    do until (eof);
      input;
      if index(_infile_,'Content-Type')
        and index(_infile_,'application/pdf') then verdict='PASS';
    end;
  end;
  call symputx('hdrverdict',verdict,'l');

  /* the platform decides what the header check can expect */
  hdrexp='NA';
  if "&mcTestPlatform"="SASJS" then hdrexp='PASS';
  call symputx('hdrexp',hdrexp,'l');
run;

%mp_assert(
  iftrue=(&dstsize=&srcsize),
  desc=Checking the PDF was copied to the destination,
  outds=work.test_results
)
%mp_assert(
  iftrue=("&hdrverdict"="&hdrexp"),
  desc=Checking the PDF content type header,
  outds=work.test_results
)
