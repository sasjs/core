/**
  @file
  @brief Adds custom quotes / delimiters to a  delimited string
  @details Can be used in open code, eg as follows:

      %put %mf_getquotedstr(blah   blah  blah);

  which returns:
> 'blah','blah','blah'

  Alternatively:

      %put %mf_getquotedstr(these words are double quoted,quote=D)

  for:
> "these","words","are","double","quoted"

  @param [in] in_str The unquoted, spaced delimited string to transform
  @param [in] dlm= (,) The delimeter to be applied to the output (default comma)
  @param [in] indlm= ( ) The delimeter used for the input (default is space)
  @param [in] quote= (S) The quote mark to apply (S=Single, D=Double, N=None).
    If any other value than uppercase S or D is supplied, then that value will
    be used as the quoting character.
  @return output returns a string with the newly quoted / delimited output.

  @version 9.2
  @author Allan Bowe
**/


%macro mf_getquotedstr(IN_STR
  ,DLM=%str(,)
  ,QUOTE=S
  ,indlm=%str( )
)/*/STORE SOURCE*/;
  /* credit Rowland Hale  - byte34 is double quote, 39 is single quote */
  %if &quote=S %then %let quote=%qsysfunc(byte(39));
  %else %if &quote=D %then %let quote=%qsysfunc(byte(34));
  %else %if &quote=N %then %let quote=;
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

%mend mf_getquotedstr;