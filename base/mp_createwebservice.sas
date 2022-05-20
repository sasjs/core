/**
  @file mp_createwebservice.sas
  @brief Create a web service in SAS 9, Viya or SASjs Server
  @details This is actually a wrapper for mx_createwebservice.sas, remaining
  for legacy purposes.  For new apps, use mx_createwebservice.sas.


  <h4> SAS Macros </h4>
  @li mx_createwebservice.sas


**/

%macro mp_createwebservice(path=HOME
    ,name=initService
    ,precode=
    ,code=ft15f001
    ,desc=This service was created by the mp_createwebservice macro
    ,replace=YES
    ,mdebug=0
)/*/STORE SOURCE*/;

  %mx_createwebservice(path=&path
    ,name=&name
    ,precode=&precode
    ,code=&code
    ,desc=&desc
    ,replace=&replace
    ,mdebug=&mdebug
  )

%mend mp_createwebservice;
