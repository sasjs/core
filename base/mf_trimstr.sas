/**
  @file mf_trimstr.sas
  @brief Removes character(s) from the end, if they exist
  @details If the designated characters exist at the end of the string, they 
  are removed

        %put %mf_trimstr(/blah/,/); * /blah;
        %put %mf_trimstr(/blah/,h); * /blah/;
        %put %mf_trimstr(/blah/,h/); */bla;

  <h4> Dependencies </h4>


  @param basestr The string to be modified
  @param trimstr The string to be removed from the end of `basestr`, if it exists

  @return output returns result with the value of `trimstr` removed from the end


  @version 9.2
  @author Allan Bowe

**/

%macro mf_trimstr(basestr,trimstr);
%local trimlen trimval;
%let trimlen=%length(%superq(trimstr));
%let trimval=%qsubstr(%superq(basestr)
  ,%length(%superq(basestr))-&trimlen+1
  ,&trimlen);

%if %superq(trimval)=%superq(trimstr) %then %do;
  %qsubstr(%superq(basestr),1,%length(%superq(basestr))-&trimlen)
%end;
%else %do;
  &basestr
%end;

%mend;