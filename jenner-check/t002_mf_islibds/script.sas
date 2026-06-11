/* mf_islibds.sas (from sasjs/core base/) - returns 1 if the argument is a
   valid two-level libref.dataset reference, else 0. Uses a Perl regex. */

%macro mf_islibds(libds
);

%local regex;
%let regex=%sysfunc(prxparse(%str(/^[_a-z]\w{0,7}\.[_a-z]\w{0,31}$/i)));

%sysfunc(prxmatch(&regex,&libds))

%mend mf_islibds;

/* Documented usage (from the macro header) */
%let valid   = %mf_islibds(work.somedata);
%let nolib   = %mf_islibds(somedata);
%let badchar = %mf_islibds(s-mething.invalid);

data work.islibds_check;
  length input $24 result $1 expected $1 pass $4;
  input='work.somedata';      result="&valid";   expected='1'; pass=ifc(result=expected,'PASS','FAIL'); output;
  input='somedata';           result="&nolib";   expected='0'; pass=ifc(result=expected,'PASS','FAIL'); output;
  input='s-mething.invalid';  result="&badchar"; expected='0'; pass=ifc(result=expected,'PASS','FAIL'); output;
run;

proc print data=work.islibds_check noobs; run;
