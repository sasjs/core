/**
  @file
  @brief Returns the length of a numeric value
  @details
  Returns the length, in bytes, of a numeric value.  If the value is
  missing, then 0 is returned.

  The function itself takes the following (positional) parameters:

  | PARAMETER | DESCRIPTION |
  |---|---|
  | var | variable (or value) to be tested|

  Usage:

      %mcf_length(wrap=YES, insert_cmplib=YES)

      data _null_;
        ina=1;
        inb=10000000;
        inc=12345678;
        ind=.;
        outa=mcf_length(ina);
        outb=mcf_length(inb);
        outc=mcf_length(inc);
        outd=mcf_length(ind);
        put (out:)(=);
      run;

  Returns:

  > outa=3 outb=4 outc=5 outd=0

  @param [out] wrap= (NO) Choose YES to add the proc fcmp wrapper.
  @param [out] lib= (work) The output library in which to create the catalog.
  @param [out] cat= (sasjs) The output catalog in which to create the package.
  @param [out] pkg= (utils) The output package in which to create the function.
    Uses a 3 part format:  libref.catalog.package
  @param [out] insert_cmplib= DEPRECATED - The CMPLIB option is checked and
    values inserted only if needed.

  <h4> SAS Macros </h4>
  @li mcf_init.sas

  <h4> Related Programs </h4>
  @li mcf_length.test.sas
  @li mp_init.sas

**/

%macro mcf_length(wrap=NO
  ,insert_cmplib=DEPRECATED
  ,lib=WORK
  ,cat=SASJS
  ,pkg=UTILS
)/*/STORE SOURCE*/;
%local i var cmpval found;
%if %mcf_init(mcf_length)=1 %then %return;

%if &wrap=YES  %then %do;
  proc fcmp outlib=&lib..&cat..&pkg;
%end;

function mcf_length(var);
  if var=. then len=0;
  else if missing(var) or trunc(var,3)=var then len=3;
  else if trunc(var,4)=var then len=4;
  else if trunc(var,5)=var then len=5;
  else if trunc(var,6)=var then len=6;
  else if trunc(var,7)=var then len=7;
  else len=8;
  return(len);
endsub;

%if &wrap=YES %then %do;
  quit;
%end;

/* insert the CMPLIB if not already there */
%let cmpval=%sysfunc(getoption(cmplib));
%let found=0;
%do i=1 %to %sysfunc(countw(&cmpval,%str( %(%))));
  %let var=%scan(&cmpval,&i,%str( %(%)));
  %if &var=&lib..&cat %then %let found=1;
%end;
%if &found=0 %then %do;
  options insert=(CMPLIB=(&lib..&cat));
%end;

%mend mcf_length;