/**
  @file
  @brief Export a dataset to a CSV file WITH leading blanks
  @details Export a dataset to a file or fileref, retaining leading blanks.

  When using SASJS headerformat, the input statement is provided in the first
  row of the CSV.

  Usage:

      %mp_ds2csv(sashelp.class,outref="%sysfunc(pathname(work))/file.csv")

      filename example temp;
      %mp_ds2csv(sashelp.air,outref=example,headerformat=SASJS)
      data; infile example; input;put _infile_; if _n_>5 then stop;run;

      data _null_;
        infile example;
        input;
        call symputx('stmnt',_infile_);
        stop;
      run;
      data work.want;
        infile example dsd firstobs=2;
        input &stmnt;
      run;

  Why use mp_ds2csv over, say, proc export?

  1. Ability to retain leading blanks (this is a major one)
  2. Control the header format
  3. Simple one-liner

  @param [in] ds The dataset to be exported
  @param [in] dlm= (COMMA) The delimeter to apply.  For SASJS, will always be
    COMMA. Supported values:
    @li COMMA
    @li SEMICOLON
  @param [in] headerformat= (LABEL) The format to use for the header section.
    Valid values:
    @li LABEL - Use the variable label (or name, if blank)
    @li NAME - Use the variable name
    @li SASJS - Used to create sasjs-formatted input CSVs, eg for use in
      mp_testservice.sas.  This format will supply an input statement in the
      first row, making ingestion by datastep a breeze.  Special misisng values
      will be prefixed with a period (eg `.A`) to enable ingestion on both SAS 9
      and Viya.  Dates / Datetimes etc are identified by the format type (lookup
      with mcf_getfmttype.sas) and converted to human readable formats (not
      numbers).
  @param [out] outfile= The output filename - should be quoted.
  @param [out] outref= (0) The output fileref (takes precedence if provided)
  @param [in] outencoding= (0) The output encoding to use (unquoted)
  @param [in] termstr= (CRLF) The line seperator to use.  For SASJS, will
    always be CRLF.  Valid values:
    @li CRLF
    @li LF

  <h4> SAS Macros </h4>
  @li mcf_getfmttype.sas
  @li mf_getuniquename.sas
  @li mf_getvarformat.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas

  @version 9.2
  @author Allan Bowe (credit mjsq)
**/

%macro mp_ds2csv(ds
  ,dlm=COMMA
  ,outref=0
  ,outfile=
  ,outencoding=0
  ,headerformat=LABEL
  ,termstr=CRLF
)/*/STORE SOURCE*/;

%local outloc delim i varlist var vcnt vat dsv vcom vmiss fmttype vfmt;

%if not %sysfunc(exist(&ds)) %then %do;
  %put %str(WARN)ING:  &ds does not exist;
  %return;
%end;

%if %index(&ds,.)=0 %then %let ds=WORK.&ds;

%if &outencoding=0 %then %let outencoding=;
%else %let outencoding=encoding="&outencoding";

%if &outref=0 %then %let outloc=&outfile;
%else %let outloc=&outref;

%if &headerformat=SASJS %then %do;
  %let delim=",";
  %let termstr=CRLF;
  %mcf_getfmttype(wrap=YES)
%end;
%else %if &dlm=COMMA %then %let delim=",";
%else %let delim=";";

/* credit to mjsq - https://stackoverflow.com/a/55642267 */

/* first get headers */
data _null_;
  file &outloc &outencoding lrecl=32767 termstr=&termstr;
  length header $ 2000 varnm vfmt $32 dlm $1 fmttype $8;
  call missing(of _all_);
  dsid=open("&ds.","i");
  num=attrn(dsid,"nvars");
  dlm=&delim;
  do i=1 to num;
    varnm=upcase(varname(dsid,i));
    if i=num then dlm='';
  %if &headerformat=NAME %then %do;
    header=cats(varnm,dlm);
  %end;
  %else %if &headerformat=LABEL %then %do;
    header = cats(coalescec(varlabel(dsid,i),varnm),dlm);
  %end;
  %else %if &headerformat=SASJS %then %do;
    if vartype(dsid,i)='C' then header=cats(varnm,':$char',varlen(dsid,i),'.');
    else do;
      vfmt=coalescec(varfmt(dsid,i),'0');
      fmttype=mcf_getfmttype(vfmt);
      if fmttype='DATE' then header=cats(varnm,':date9.');
      else if fmttype='DATETIME' then header=cats(varnm,':E8601DT26.6');
      else if fmttype='TIME' then header=cats(varnm,':TIME12.');
      else header=cats(varnm,':best.');
    end;
  %end;
  %else %do;
    %put &sysmacroname: Invalid headerformat value (&headerformat);
    %return;
  %end;
    put header @;
  end;
  rc=close(dsid);
run;

%let varlist=%mf_getvarlist(&ds);
%let vcnt=%sysfunc(countw(&varlist));

/**
  * The $quote modifier (without a width) will take the length from the variable
  * and increase by two.  However this will lead to truncation where the value
  * contains double quotes (which are doubled up).  To get around this, scan the
  * data to see the max number of double quotes, so that the appropriate width
  * can be applied in the subsequent step.
  */
data _null_;
  set &ds end=last;
%do i=1 %to &vcnt;
  %let var=%scan(&varlist,&i);
  %if %mf_getvartype(&ds,&var)=C %then %do;
    %let dsv1=%mf_getuniquename(prefix=csvcol1_);
    %let dsv2=%mf_getuniquename(prefix=csvcol2_);
    retain &dsv1 0;
    &dsv2=length(&var)+countc(&var,'"');
    if &dsv2>&dsv1 then &dsv1=&dsv2;
    if last then call symputx(
      "vlen&i"
      /* should be no shorter than varlen, and no longer than 32767 */
      ,cats('$quote',min(&dsv1+2,32767),'.')
      ,'l'
    );
  %end;
%end;

%let vat=@;
%let vcom=&delim;
%let vmiss=%mf_getuniquename(prefix=csvcol3_);
/* next, export data */
data _null_;
  set &ds.;
  file &outloc mod dlm=&delim dsd &outencoding lrecl=32767 termstr=&termstr;
  if _n_=1 then &vmiss='  ';
  %do i=1 %to &vcnt;
    %let var=%scan(&varlist,&i);
    %if &i=&vcnt %then %do;
      %let vat=;
      %let vcom=;
    %end;
    %if %mf_getvartype(&ds,&var)=N %then %do;
      %if &headerformat = SASJS %then %do;
        %let vcom=&delim;
        %let fmttype=%sysfunc(mcf_getfmttype(%mf_getvarformat(&ds,&var)0));
        %if &fmttype=DATE %then %let vfmt=DATE9.;
        %else %if &fmttype=DATETIME %then %let vfmt=E8601DT26.6;
        %else %if &fmttype=TIME %then %let vfmt=TIME12.;
        %else %do;
          %let vfmt=;
          %let vcom=;
        %end;
      %end;
      %else %let vcom=;

      /* must use period - in order to work in both 9.4 and Viya 3.5 */
      if missing(&var) and &var ne %sysfunc(getoption(MISSING)) then do;
        &vmiss=cats('.',&var);
        put &vmiss &vat;
      end;
      else put &var &vfmt &vcom &vat;

    %end;
    %else %do;
      %if &i ne &vcnt %then %let vcom=&delim;
      put &var &&vlen&i &vcom &vat;
    %end;
  %end;
run;

%mend mp_ds2csv;