/**
  @file
  @brief Creates a Unique ID based on system time in a friendly format
  @details format = YYYYMMDD_HHMMSSmmm_<sysjobid>_<3randomDigits>

        %put %mf_uid();

  @version 9.2
  @author Allan Bowe

**/

%macro mf_uid(
)/*/STORE SOURCE*/;
  %local today now;
  %let today=%sysfunc(today(),yymmddn8.);
  %let now=%sysfunc(compress(%sysfunc(time(),time12.3),:.));

  &today._&now._&sysjobid._%sysevalf(%sysfunc(ranuni(0))*999,CEIL)

%mend;