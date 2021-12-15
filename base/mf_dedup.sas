/**
  @file
  @brief de-duplicates a macro string
  @details Removes all duplicates from a string of words.  A delimeter can be
  chosen.  Is inspired heavily by this excellent [macro](
  https://github.com/scottbass/SAS/blob/master/Macro/dedup_mstring.sas) from
  [Scott Base](https://www.linkedin.com/in/scottbass).  Case sensitive.

  Usage:

      %let str=One two one two and through and through;
      %put %mf_dedup(&str);
      %put %mf_dedup(&str,outdlm=%str(,));

  Which returns:

      > One two one and through
      > One,two,one,and,through

  @param [in] str String to be deduplicated
  @param [in] indlm= ( ) Delimeter of the input string
  @param [out] outdlm= ( ) Delimiter of the output string

  <h4> Related Macros </h4>
  @li mf_trimstr.sas
  @li mf_wordsinstr1butnotstr2.sas

  @version 9.2
  @author Allan Bowe
**/

%macro mf_dedup(str
  ,indlm=%str( )
  ,outdlm=%str( )
)/*/STORE SOURCE*/;

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


