/**
  @file
  @brief Creates a unique ID based on system time in friendly format
  @details format = YYYYMMDD_HHMMSSmmm_<sysjobid>_<3randomDigits>

        %put %mf_uid();

  @version 9.3
  @author Allan Bowe

**/

%macro mf_uid(
)/*/STORE SOURCE*/;
  %local today now;
  %let today=%sysfunc(today(),yymmddn8.);
  %let now=%sysfunc(compress(%sysfunc(time(),tod12.3),:.));

  &today._&now._&sysjobid._%sysevalf(%sysfunc(ranuni(0))*999,CEIL)

%mend;