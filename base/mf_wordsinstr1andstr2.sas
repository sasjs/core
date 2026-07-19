/**
  @file
  @brief Returns words that are in both string 1 and string 2
  @details  Compares two space separated strings and returns the words that are
  in both.

  If either string is empty, nothing is returned.

  Usage:

      %put %mf_wordsinstr1andstr2(
        Str1=blah sss blaaah brah bram boo
        ,Str2=   blah blaaah brah ssss
      );

  returns:
  > blah blaaah brah

  @param [in] str1= () string containing words to extract
  @param [in] str2= () used to compare with the extract string

  @warning CASE SENSITIVE!

  @version 9.2
  @author Allan Bowe

**/

%macro mf_wordsinstr1andstr2(
  Str1= /* string containing words to extract */
  ,Str2= /* used to compare with the extract string */
)/*/STORE SOURCE*/;

%local count_extr i extr_word outvar;
%if %length(&str1)=0 or %length(&str2)=0 %then %do;
  %put &sysmacroname: empty input string, nothing to compare;
  %return;
%end;
%let count_extr=%sysfunc(countw(&Str1));

%do i=1 %to &count_extr;
  %let extr_word=%scan(&Str1,&i,%str( ));
  %if %sysfunc(indexw(%superq(str2),%superq(extr_word)))>0 %then
    %let outvar=&outvar &extr_word;
%end;
/* send out the result without any surrounding whitespace */
%do;&outvar%end;
%mend mf_wordsinstr1andstr2;
