/* mf_mval.sas (from sasjs/core base/) - returns the value of a macro
   variable if it exists, else an empty string (no WARNING). */

%macro mf_mval(var);
  %if %symexist(&var) %then %do;
    %superq(&var)
  %end;
%mend mf_mval;

/* Documented usage */
%global myvar;
%let myvar=hello world;
%let exists  = %mf_mval(myvar);
%let missing = %mf_mval(doesnotexist);

data work.mval_check;
  length scenario $20 result $40 expected $40 pass $4;
  scenario='defined var';   result="&exists";  expected='hello world'; pass=ifc(strip(result)=strip(expected),'PASS','FAIL'); output;
  scenario='undefined var'; result="&missing"; expected='';            pass=ifc(strip(result)=strip(expected),'PASS','FAIL'); output;
run;

proc print data=work.mval_check noobs; run;
