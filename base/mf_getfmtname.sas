/**
  @file
  @brief Extracts a format name from a fully defined format
  @details Converts formats in like $thi3. and th13.2 $THI and TH.
  Usage:

      %put %mf_getfmtname(8.);
      %put %mf_getfmtname($4.);
      %put %mf_getfmtname(comma14.10);

  Returns:

  > W
  > $CHAR
  > COMMA

  Note that system defaults are inferred from the values provided.

  @param [in] fmt The fully defined format. If left blank, nothing is returned.

  @returns The name (without width or decimal) of the format.

  @version 9.2
  @author Allan Bowe

**/

%macro mf_getfmtname(fmt
)/*/STORE SOURCE*/ /minoperator mindelimiter=' ';

%local out dsid nvars x rc fmt;

/* extract actual format name from the format definition */
%let fmt=%scan(&fmt,1,.);
%do %while(%substr(&fmt,%length(&fmt),1) in 1 2 3 4 5 6 7 8 9 0);
  %if %length(&fmt)=1 %then %let fmt=W;
  %else %let fmt=%substr(&fmt,1,%length(&fmt)-1);
%end;

%if &fmt=$ %then %let fmt=$CHAR;

/* send them out without spaces or quote markers */
%do;%unquote(%upcase(&fmt))%end;
%mend mf_getfmtname;