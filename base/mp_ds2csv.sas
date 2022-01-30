/**
  @file
  @brief Export a dataset to a CSV file WITH leading blanks
  @details Export a dataset to a file or fileref, retaining leading blanks.

  Usage:

      %mp_ds2csv(sashelp.class,outref="%sysfunc(pathname(work))/file.csv")

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
      mp_testservice.sas
  @param [out] outfile= The output filename - should be quoted.
  @param [out] outref= (0) The output fileref (takes precedence if provided)
  @param [in] outencoding= (0) The output encoding to use (unquoted)
  @param [in] termstr= (CRLF) The line seperator to use.  For SASJS, will
    always be CRLF.  Valid values:
    @li CRLF
    @li LF

  <h4> SAS Macros </h4>
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

%local outloc delim i varlist var vcnt vat dsv;

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
%end;
%else %if &dlm=COMMA %then %let delim=",";
%else %let delim=";";

/* credit to mjsq - https://stackoverflow.com/a/55642267 */

/* first get headers */
data _null_;
  file &outloc &outencoding lrecl=32767 termstr=&termstr;
  length header $ 2000 varnm $32;
  dsid=open("&ds.","i");
  num=attrn(dsid,"nvars");
  do i=1 to num;
    varnm=upcase(varname(dsid,i));
  %if &headerformat=NAME %then %do;
    header=cats(varnm,&delim);
  %end;
  %else %if &headerformat=LABEL %then %do;
    header = cats(coalescec(varlabel(dsid,i),varnm),&delim);
  %end;
  %else %if &headerformat=SASJS %then %do;
    if vartype(dsid,i)='C' then header=cats(varnm,':$char',varlen(dsid,i),'.');
    else header=cats(varnm,':best.');
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
/* next, export data */
data _null_;
  set &ds.;
  file &outloc mod dlm=&delim dsd &outencoding lrecl=32767 termstr=&termstr;
  %do i=1 %to &vcnt;
    %let var=%scan(&varlist,&i);
    %if &i=&vcnt %then %let vat=;
    %if %mf_getvartype(&ds,&var)=N %then %do;
      put &var &vat;
    %end;
    %else %do;
      put &var &&vlen&i "," &vat;
    %end;
  %end;
run;

%mend mp_ds2csv;