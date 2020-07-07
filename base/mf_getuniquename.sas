/**
  @file mf_getuniquename.sas
  @brief Returns a shortened (32 char) GUID as a valid SAS name
  @details Use as follows:

      %let myds=%mf_getuniquename();
      %put &=myds;

  which returns:

> MCc59c750610321d4c8bf75faadbcd22

  @param prefix= set a prefix for the new name

  @version 9.3
  @author Allan Bowe
**/


%macro mf_getuniquename(prefix=MC);
  &prefix.%substr(%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32-%length(&prefix))
%mend;