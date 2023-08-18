/**
  @file mf_mval.sas
  @brief Returns a macro variable value if the variable exists
  @details
  Use this macro to avoid repetitive use of `%if %symexist(MACVAR) %then`
  type logic.
  Usage:

      %if %mf_mval(maynotexist)=itdid %then %do;

  @param [in] var The macro variable NAME to return the (possible) value for

  @version 9.2
  @author Allan Bowe
**/

%macro mf_mval(var);
  %if %symexist(&var) %then %do;
    %superq(&var)
  %end;
%mend mf_mval;
