/**
  @file mf_isblank.sas
  @brief Checks whether a macro variable is empty (blank)
  @details Simply performs:

      %sysevalf(%superq(param)=,boolean)

  Usage:

      %put mf_isblank(&var);

  inspiration:
  https://support.sas.com/resources/papers/proceedings09/022-2009.pdf

  @param param VALUE to be checked

  @return output returns 1 (if blank) else 0

  @version 9.2
**/

%macro mf_isblank(param
)/*/STORE SOURCE*/;

  %sysevalf(%superq(param)=,boolean)

%mend;