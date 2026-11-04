/**
  @file mf_trimstr.sas
  @brief Removes character(s) from the end, if they exist
  @details If the designated characters exist at the end of the string, they
  are removed

        %put %mf_trimstr(/blah/,/); * /blah;
        %put %mf_trimstr(/blah/,h); * /blah/;
        %put %mf_trimstr(/blah/,h/);* /bla;

  <h4> SAS Macros </h4>


  @param [in] basestr The string to be modified
  @param [in] trimstr The string to be removed from the end of `basestr`, if it
    exists

  @return output returns result with the value of `trimstr` removed from the end


  @version 9.2
  @author Allan Bowe

**/

%macro mf_trimstr(basestr,trimstr);
%local baselen trimlen trimval;

%let baselen=%length(%superq(basestr));
%let trimlen=%length(%superq(trimstr));

/* nothing to remove from nothing */
%if &baselen=0 %then %return;

%if &baselen < &trimlen %then %do;
  /* a value shorter than the trim string cannot end with it, so it is
    returned unchanged - returning nothing here lost the value */
  &basestr
%end;
%else %do;
  /* obtain the characters from the end of basestr */
  %let trimval=%qsubstr(%superq(basestr)
    ,&baselen-&trimlen+1
    ,&trimlen);

  /* compare and if matching, chop it off! */
  %if %superq(basestr)=%superq(trimstr) %then %do;
    %return;
  %end;
  %else %if %superq(trimval)=%superq(trimstr) %then %do;
    %qsubstr(%superq(basestr),1,&baselen-&trimlen)
  %end;
  %else %do;
    &basestr
  %end;
%end;

%mend mf_trimstr;
