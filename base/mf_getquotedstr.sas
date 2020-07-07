/**
  @file
  @brief Adds custom quotes / delimiters to a  delimited string
  @details Can be used in open code, eg as follows:

    %put %mf_getquotedstr(blah   blah  blah);

  which returns:
> 'blah','blah','blah'

  @param in_str the unquoted, spaced delimited string to transform
  @param dlm= the delimeter to be applied to the output (default comma)
  @param indlm= the delimeter used for the input (default is space)
  @param quote= the quote mark to apply (S=Single, D=Double). If any other value
    than uppercase S or D is supplied, then that value will be used as the
    quoting character.
  @return output returns a string with the newly quoted / delimited output.

  @version 9.2
  @author Allan Bowe
**/


%macro mf_getquotedstr(IN_STR,DLM=%str(,),QUOTE=S,indlm=%str( )
)/*/STORE SOURCE*/;
  %if &quote=S %then %let quote=%str(%');
  %else %if &quote=D %then %let quote=%str(%");
  %else %let quote=%str();
  %local i item buffer;
  %let i=1;
  %do %while (%qscan(&IN_STR,&i,%str(&indlm)) ne %str() ) ;
    %let item=%qscan(&IN_STR,&i,%str(&indlm));
    %if %bquote(&QUOTE) ne %then %let item=&QUOTE%qtrim(&item)&QUOTE;
    %else %let item=%qtrim(&item);

    %if (&i = 1) %then %let buffer =%qtrim(&item);
    %else %let buffer =&buffer&DLM%qtrim(&item);

    %let i = %eval(&i+1);
  %end;

  %let buffer=%sysfunc(coalescec(%qtrim(&buffer),&QUOTE&QUOTE));

  &buffer

%mend;