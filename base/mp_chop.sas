/**
  @file
  @brief Splits a file of ANY SIZE by reference to a search string.
  @details Provide a fileref and a search string to chop off part of a file.

  Works by reading in the file byte by byte, then marking the beginning and end
  of each matched string, before finally doing the chop.

  Choose whether to keep the FIRST or the LAST section of the file.  Optionally,
  use an OFFSET to fix the precise chop point.

  Usage:

      %let src="%sysfunc(pathname(work))/file.txt";
      %let str=Chop here!;
      %let out1="%sysfunc(pathname(work))/file1.txt";
      %let out2="%sysfunc(pathname(work))/file2.txt";
      %let out3="%sysfunc(pathname(work))/file3.txt";
      %let out4="%sysfunc(pathname(work))/file4.txt";

      data _null_;
        file &src;
        put "startsection&str.endsection";
      run;

      %mp_chop(&src, matchvar=str, keep=FIRST, outfile=&out1)
      %mp_chop(&src, matchvar=str, keep=LAST, outfile=&out2)
      %mp_chop(&src, matchvar=str, keep=FIRST, matchpoint=END, outfile=&out3)
      %mp_chop(&src, matchvar=str, keep=LAST, matchpoint=END, outfile=&out4)

      filename results (&out1 &out2 &out3 &out4);
      data _null_;
        infile results;
        input;
        list;
      run;

  Results:
    @li `startsection`
    @li `Chop here!endsection`
    @li `startsectionChop here!`
    @li `endsection`

  For more examples, see mp_chop.test.sas

  @param [in] infile The QUOTED path to the file on which to perform the chop
  @param [in] matchvar= Macro variable NAME containing the string to split by
  @param [in] matchpoint= (START) Valid values:
    @li START - chop at the beginning of the string in `matchvar`.
    @li END - chop at the end of the string in `matchvar`.
  @param [in] offset= (0) An adjustment to the precise chop location, by
    by reference to the `matchpoint`. Should be a positive or negative integer.
  @param [in] keep= (FIRST) Valid values:
    @li FIRST - keep the section of the file before the chop
    @li LAST - keep the section of the file after the chop
  @param [in] mdebug= (0) Set to 1 to provide macro debugging
  @param outfile= (0) Optional QUOTED path to the adjusted output file (avoids
    overwriting the first file).

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas

  <h4> Related Macros </h4>
  @li mp_abort.sas
  @li mp_gsubfile.sas
  @li mp_replace.sas
  @li mp_chop.test.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mp_chop(infile,
  matchvar=,
  matchpoint=START,
  keep=FIRST,
  offset=0,
  mdebug=0,
  outfile=0
)/*/STORE SOURCE*/;

%local fref0 dttm ds1 outref;
%let fref0=%mf_getuniquefileref();
%let ds1=%mf_getuniquename(prefix=allchars);
%let ds2=%mf_getuniquename(prefix=startmark);

%if &outfile=0 %then %let outfile=&infile;

%mp_abort(iftrue= (%length(%superq(&matchvar))=0)
  ,mac=mp_chop.sas
  ,msg=%str(&matchvar is an empty variable)
)

/* START */
%let dttm=%sysfunc(datetime());

filename &fref0 &infile lrecl=1 recfm=n;

/* create dataset with one char per row */
data &ds1;
  infile &fref0;
  input sourcechar $char1. @@;
  format sourcechar hex2.;
run;

/* get start & stop position of first matchvar string (one row, two vars) */
data &ds2;
  /* set find string to length in bytes to cover trailing spaces */
  length string $ %length(%superq(&matchvar));
  string =symget("&matchvar");
  drop string;

  firstchar=char(string,1);
  findlen=lengthm(string); /* <- for trailing bytes */

  do _N_=1 to nobs;
    set &ds1 nobs=nobs point=_N_;
    if sourcechar=firstchar then do;
      pos=1;
      s=0;
      do point=_N_ to min(_N_ + findlen -1,nobs);
        set &ds1 point=point;
        if sourcechar=char(string, pos) then s + 1;
        else goto _leave_;
        pos+1;
      end;
      _leave_:
      if s=findlen then do;
        START =_N_;
        _N_ =_N_+ s - 1;
        STOP =_N_;
        output;
        /* matched! */
        stop;
      end;
    end;
  end;
  stop;
  keep START STOP;
run;

%local split;
%let split=0;
data _null_;
  set &ds2;
  if "&matchpoint"='START' then do;
    if "&keep"='FIRST' then mp=start;
    else if "&keep"='LAST' then mp=start-1;
  end;
  else if "&matchpoint"='END' then do;
    if "&keep"='FIRST' then mp=stop+1;
    else if "&keep"='LAST' then mp=stop;
  end;
  split=mp+&offset;
  call symputx('split',split,'l');
%if &mdebug=1 %then %do;
  put (_all_)(=);
  %put &=offset;
%end;
run;
%if &split=0 %then %do;
  %put &sysmacroname: No match found in &infile for string %superq(&matchvar);
  %return;
%end;

data _null_;
  file &outfile recfm=n;
  set &ds1;
%if &keep=FIRST %then %do;
  if _n_ ge &split then stop;
%end;
%else %do;
  if _n_ gt &split;
%end;
  put sourcechar char1.;
run;

%if &mdebug=0 %then %do;
  filename &fref0 clear;
%end;
%else %do;
  data _null_;
    infile &outfile lrecl=32767;
    input;
    list;
    if _n_>200 then stop;
  run;
%end;
/* END */
%put &sysmacroname took %sysevalf(%sysfunc(datetime())-&dttm) seconds to run;

%mend mp_chop;
