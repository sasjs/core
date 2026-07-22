/**
  @file
  @brief Testing mp_jsonout.sas macro with non-standard chars

  <h4> SAS Macros </h4>
  @li mp_jsonout.sas
  @li mp_assert.sas

**/

filename webref temp;

data demo;
  length x $100;
  do x='"','0A'x,'0D'x,'09'x,'00'x,'0E'x,'0F'x,'01'x,'02'x,'10'x,'11'x,'\';
    output;
  end;
  /* embedded quote variants */
  x='say "hi" there'; output;
  x='"fully quoted"'; output;
  x='back\slash'; output;
  x='quote and back\"slash'; output;
  /* leading / trailing blank variants */
  x='  leading blanks'; output;
  x='  "leading blanks and quotes"'; output;
  x='trailing blanks  '; output;
  x='  both  '; output;
run;
%mp_jsonout(OPEN,jref=webref)
%mp_jsonout(OBJ,demo,jref=webref)
%mp_jsonout(CLOSE,jref=webref)

data _null_;
  infile webref;
  input;
  putlog _infile_;
run;

libname web JSON fileref=webref;

%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking for error condition with special chars export,
  outds=work.test_results
)

/*
data _null_;
  set work.demo (in=start) web.demo (in=end);
  put (_all_)(=);
run;
proc sql;
describe table work.demo;
describe table web.demo;
*/

proc compare base=work.demo compare=web.demo(keep=x);
quit;

/* sysinfo is a bitmask - keep only data-related bits, ie:
  64    Base data set has observation not in comparison
  128   Comparison data set has observation not in base
  4096  A value comparison was unequal
  32768 Number of observations differ
  Attribute diffs (eg 16 - variable length) are ignored, as a JSON
  round trip will not preserve lengths/formats/labels.
*/
/* SYSINFO is read only, so store the masked value in a new variable */
%let sysinfo_masked=%sysfunc(band(&sysinfo, 64+128+4096+32768));

%mp_assert(
  iftrue=(&sysinfo_masked=0),
  desc=Returned json is identical to input table for all special chars,
  outds=work.test_results
)
