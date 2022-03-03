/**
  @file
  @brief Performs a text substitution on a file
  @details Reads a file in byte by byte, performing text substiution where a
  match is found.

  This macro can be used on files where lines are longer than 32767.

  If you are running a version of SAS that will allow the io package in LUA, you
  can also use this macro: mp_gsubfile.sas

  Usage:

      %let file="%sysfunc(pathname(work))/file.txt";
      %let str=replace/me;
      %let rep=with/this;
      data _null_;
        file &file;
        put 'blahblah';
        put "blahblah&str.blah";
        put 'blahblahblah';
      run;
      %mp_replace(&file, findvar=str, replacevar=rep)
      data _null_;
        infile &file;
        input;
        list;
      run;

  @param infile The QUOTED path to the file on which to perform the substitution
  @param findvar= Macro variable NAME containing the string to search for
  @param replacevar= Macro variable NAME containing the replacement string
  @param outfile= (0) Optional QUOTED path to an the adjusted output file (to
    avoid overwriting the first file).

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas

  <h4> Related Macros </h4>
  @li mp_gsubfile.test.sas

  @version 9.4
  @author Allan Bowe
**/

%macro mp_replace(infile,
  findvar=,
  replacevar=,
  outfile=0
)/*/STORE SOURCE*/;

%local inref dttm ds1;
%let inref=%mf_getuniquefileref();
%let outref=%mf_getuniquefileref();
%if &outfile=0 %then %let outfile=&infile;
%let ds1=%mf_getuniquename(prefix=allchars);
%let ds2=%mf_getuniquename(prefix=startmark);

/* START */
%let dttm=%sysfunc(datetime());

filename &inref &infile lrecl=1 recfm=n;

data &ds1;
  infile &inref;
  input x $ 1. @@;
  format x hex2.;
run;

data &ds2;

  /* set find string to length in bytes to cover trailing spaces */
  length string $ %length(%superq(&findvar));
  string =symget("&findvar");
  drop string;

  z =char(string,1);
  l =lengthm(string); /* <- for trailing bytes */

  do _N_ =1 to nobs;
    set &ds1 nobs=nobs point=_N_;
    if x =z then do;
      pos =1;
      s =0;
      do point =_N_ to min(_N_ + l -1,nobs);
        set &ds1 point=point;
        if x =char(string, pos) then s + 1;
        else goto _leave_;
        pos+1;
      end;
      _leave_:
      if s =l then do;
        START =_N_;
        _N_ =_N_+ s - 1;
        STOP =_N_;
        output;
      end;
      else _N_ =_N_+ s;
    end;
  end;
  stop;
  keep START STOP;
run;

data &ds1;
  declare hash HS(dataset:"&ds2(keep=start)");
  HS.defineKey("start");
  HS.defineDone();

  declare hash HE(dataset:"&ds2(keep=stop)");
  HE.defineKey("stop");
  HE.defineDone();

  do until(eof);
    set &ds1 end=eof curobs =n;

    start=0;
    stop=0;
    if 0 =HS.check(key:n) then start =1;
    if 0 =HE.check(key:n) then stop  =1;

    length strt $ 1;
    strt =put(start,best. -L);

    retain out 1;
    if out   then output;
    if start then out=0;
    if stop  then out=1;
  end;

  stop;

  keep x strt;
run;

filename &outref &outfile recfm=n;

data _null_;
  length replace $ %length(%superq(&replacevar));
  replace=symget("&replacevar");
  file &outref;
  do until(eof);
    set &ds1 end=eof;
    if strt ="1" then put replace char.;
    else put x char1.;
  end;
  stop;
run;

/* END */
%put &sysmacroname took %sysevalf(%sysfunc(datetime())-&dttm) seconds to run;

%mend mp_replace;
