/**
  @file
  @brief Returns words that are in string 1 but not in string 2
  @details  Compares two space separated strings and returns the words that are
  in the first but not in the second.

  Note - case sensitive!

  If str1 is empty, nothing is returned.  If str2 is empty, all the words in
  str1 are returned.

  Usage:

      %let x= %mf_wordsinstr1butnotstr2(
        Str1=blah sss blaaah brah bram boo
        ,Str2=   blah blaaah brah ssss
      );

  returns:
  > sss bram boo

  @param [in] str1= () String containing words to extract
  @param [in] str2= () Used to compare with the extract string

  @version 9.2
  @author Allan Bowe

**/

%macro mf_wordsinstr1butnotstr2(
  Str1= /* string containing words to extract */
  ,Str2= /* used to compare with the extract string */
)/*/STORE SOURCE*/;

%local count_extr i extr_word outvar;
%if %length(&str1)=0 %then %do;
  %put &sysmacroname: str1 is empty, nothing to compare;
  %return;
%end;
%let count_extr=%sysfunc(countw(&Str1));

%do i=1 %to &count_extr;
  %let extr_word=%scan(&Str1,&i,%str( ));
  %if %sysfunc(indexw(%superq(str2),%superq(extr_word)))=0 %then
    %let outvar=&outvar &extr_word;
%end;
/* send out the result without any surrounding whitespace */
%do;&outvar%end;
%mend mf_wordsinstr1butnotstr2;
