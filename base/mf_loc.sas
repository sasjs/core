/**
  @file
  @brief Returns physical location of various SAS items
  @details Returns location of the PlatformObjectFramework tools
    Usage:

      %put %mf_loc(POF); %*location of PlatformObjectFramework tools;

  @param [in] loc The item to locate, eg:
    @li PLAATFORMOBJECTFRAMEWORK (or POF)
    @li VIYACONFG

  @version 9.2
  @author Allan Bowe
**/

%macro mf_loc(loc);
%let loc=%upcase(&loc);
%local root;

%if &loc=POF or &loc=PLATFORMOBJECTFRAMEWORK %then %do;
  %let root=%sysget(SASROOT);
  %let root=%substr(&root,1,%index(&root,SASFoundation)-2);
  %let root=&root/SASPlatformObjectFramework/&sysver;
  %put Batch tools located at: &root;
  &root
%end;
%else %if &loc=VIYACONFIG %then %do;
  %let root=/opt/sas/viya/config;
  %put Viya Config located at: &root;
  &root
%end;

%mend mf_loc;
