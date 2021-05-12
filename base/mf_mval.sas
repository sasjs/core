/**
  @file mf_mval.sas
  @brief Returns a macro variable value if the variable exists
  @details
  Use this macro to avoid repetitive use of `%if %symexist(MACVAR) %then`
  type logic.
  Usage:

      %if %mf_mval(maynotexist)=itdid %then %do;

  @version 9.2
  @author Allan Bowe
**/

%macro mf_mval(var);
  %if %symexist(&var) %then %do;
    %superq(&var)
  %end;
%mend;
