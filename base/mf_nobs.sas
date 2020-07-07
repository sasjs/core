/**
  @file
  @brief Returns number of logical (undeleted) observations.
  @details Beware - will not work on external database tables!
  Is just a convenience macro for calling <code> %mf_getattrn()</code>.

        %put Number of observations=%mf_nobs(sashelp.class);

  <h4> Dependencies </h4>
  @li mf_getattrn.sas

  @param libds library.dataset

  @return output returns result of the attrn value supplied, or log message
    if error.


  @version 9.2
  @author Allan Bowe

**/

%macro mf_nobs(libds
)/*/STORE SOURCE*/;
  %mf_getattrn(&libds,NLOBS)
%mend;