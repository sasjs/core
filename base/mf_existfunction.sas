/**
  @file
  @brief Checks if a function exists
  @details Returns 1 if the function exists, else 0.  Note that this function
  can be slow as it needs to open the sashelp.vfuncs table.

  Usage:

      %put %mf_existfunction(CAT);
      %put %mf_existfunction(DOG);

  Full credit to [Bart](https://sasensei.com/user/305) for the vfunc pointer
  and the tidy approach for pure macro data set filtering.
  Check out his [SAS Packages](https://github.com/yabwon/SAS_PACKAGES)
  framework!  Where you can find the same [function](
https://github.com/yabwon/SAS_PACKAGES/blob/main/packages/baseplus.md#functionexists-macro
  ).

  @param [in] name (positional) - function name

  @author Allan Bowe
**/
/** @cond */
%macro mf_existfunction(name
)/*/STORE SOURCE*/;

  %local dsid rc exist;
  %let dsid=%sysfunc(open(sashelp.vfunc(where=(fncname="%upcase(&name)"))));
  %let exist=1;
  %let exist=%sysfunc(fetch(&dsid, NOSET));
  %let rc=%sysfunc(close(&dsid));

  %sysevalf(0 = &exist)

%mend mf_existfunction;

/** @endcond */