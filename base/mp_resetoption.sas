/**
  @file
  @brief Reset an option to original value
  @details Inspired by the SAS Jedi - https://blogs.sas.com/content/sastraining/2012/08/14/jedi-sas-tricks-reset-sas-system-options/
    Called as follows:

    options obs=30;
    %mp_resetoption(OBS)


  @param option the option to reset

  @version 9.2
  @author Allan Bowe

**/

%macro mp_resetoption(option /* the option to reset */
)/*/STORE SOURCE*/;

data _null_;
  length code  $1500;
  startup=getoption("&option",'startupvalue');
  current=getoption("&option");
  if startup ne current then do;
    code =cat('OPTIONS ',getoption("&option",'keyword','startupvalue'),';');
    putlog "NOTE: Resetting system option: " code ;
    call execute(code );
  end;
run;

%mend;