/* mf_dedup.sas (from sasjs/core base/) - de-duplicates a macro string. */
/* Header doc + STORE SOURCE annotation comments removed so the definition
   parses standalone; macro logic is unchanged. */

%macro mf_dedup(str
  ,indlm=%str( )
  ,outdlm=%str( )
);

%local num word i pos out;

%* loop over each token, searching the target for that token ;
%let num=%sysfunc(countc(%superq(str),%str(&indlm)));
%do i=1 %to %eval(&num+1);
  %let word=%scan(%superq(str),&i,%str(&indlm));
  %let pos=%sysfunc(indexw(&out,&word,%str(&outdlm)));
  %if (&pos eq 0) %then %do;
    %if (&i gt 1) %then %let out=&out%str(&outdlm);
    %let out=&out&word;
  %end;
%end;

%unquote(&out)

%mend mf_dedup;

/* Documented usage (from the macro header and tests/base/mf_dedup.test.sas) */
%let str=One two one two and through and through;
%let result=%mf_dedup(&str);

data work.dedup_check;
  length input $80 deduplicated $80 expected $80 pass $4;
  input = "&str";
  deduplicated = "&result";
  expected = "One two one and through";
  pass = ifc(strip(deduplicated)=strip(expected),'PASS','FAIL');
run;

proc print data=work.dedup_check noobs; run;
