/**
  @file
  @brief Returns the appLoc from the _program variable
  @details When working with SASjs apps, web services / tests / jobs are always
  deployed to a root (app) location in the SAS logical folder tree.

  When building apps for use in other environments, you do not necessarily know
  where the backend services will be deployed.  Therefore a function like this
  is handy in order to dynamically figure out the appLoc, and enable other
  services to be connected by a relative reference.

  SASjs apps always have the same immediate substructure (one or more of the
  following):

  @li /data
  @li /jobs
  @li /services
  @li /tests/jobs
  @li /tests/services
  @li /tests/macros

  This function works by testing for the existence of any of the above in the
  automatic _program variable, and returning the part to the left of it.

  Usage:

      %put %mf_getapploc(&_program)

      %put %mf_getapploc(/some/location/services/admin/myservice);
      %put %mf_getapploc(/some/location/jobs/extract/somejob/);
      %put %mf_getapploc(/some/location/tests/jobs/somejob/);


  @author Allan Bowe
**/

%macro mf_getapploc(pgm);
%if "&pgm"="" %then %do;
  %if %symexist(_program) %then %let pgm=&_program;
  %else %do;
    %put &sysmacroname: No value provided and no _program variable available;
    %return;
  %end;
%end;
%local root;

/**
  * First check we are not in the tests/macros folder (which has no subfolders)
  */
%if %index(&pgm,/tests/macros/) %then %do;
  %let root=%substr(&pgm,1,%index(&pgm,/tests/macros)-1);
  &root
  %return;
%end;

/**
  * Next, move up two levels to avoid matches on subfolder or service name
  */
%let root=%substr(&pgm,1,%length(&pgm)-%length(%scan(&pgm,-1,/))-1);
%let root=%substr(&root,1,%length(&root)-%length(%scan(&root,-1,/))-1);

%if %index(&root,/tests/) %then %do;
  %let root=%substr(&root,1,%index(&root,/tests/)-1);
%end;
%else %if %index(&root,/services) %then %do;
  %let root=%substr(&root,1,%index(&root,/services)-1);
%end;
%else %if %index(&root,/jobs) %then %do;
  %let root=%substr(&root,1,%index(&root,/jobs)-1);
%end;
%else %put &sysmacroname: Could not find an app location from &pgm;
  &root
%mend mf_getapploc ;