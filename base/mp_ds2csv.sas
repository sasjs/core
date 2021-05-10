/**
  @file
  @brief Export a dataset to a CSV file
  @details Export to a file or a fileref
  Usage:

      %mp_ds2csv(sashelp.class,outref="%sysfunc(pathname(work))/file.csv")

  @param ds The dataset to be exported
  @param outfile= The output filename - should be quoted.
  @param outref= The output fileref (takes precedence if provided)
  @param outencoding= The output encoding to use (unquoted)

  @version 9.2
  @author Allan Bowe (credit mjsq)
**/

%macro mp_ds2csv(ds, outref=0, outfile=, outencoding=0
)/*/STORE SOURCE*/;

%if not %sysfunc(exist(&ds)) %then %do;
  %put %str(WARN)ING:  &ds does not exist;
  %return;
%end;

%if %index(&ds,.)=0 %then %let ds=WORK.&ds;

%if &outencoding=0 %then %let outencoding=;
%else %let outencoding=encoding="&outencoding";

%local outloc;
%if &outref=0 %then %let outloc=&outfile;
%else %let outloc=&outref;

/* credit to mjsq - https://stackoverflow.com/a/55642267 */

/* first get headers */
data _null_;
  file &outloc dlm=',' dsd &outencoding lrecl=32767;
  length header $ 2000;
  dsid=open("&ds.","i");
  num=attrn(dsid,"nvars");
  do i=1 to num;
    header = trim(left(coalescec(varlabel(dsid,i),varname(dsid,i))));
    put header @;
  end;
  rc=close(dsid);
run;

/* next, export data */
data _null_;
  set &ds.;
  file &outloc mod dlm=',' dsd &outencoding lrecl=32767;
  put (_all_) (+0);
run;


%mend;