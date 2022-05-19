/**
  @file
  @brief To be deprecated.  Will execute a SASjs web service on SAS 9 or Viya
  @details Use the mx_testservice.sas macro instead (documentation can be
  found there)

  <h4> SAS Macros </h4>
  @li mx_testservice.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mp_testservice(program,
  inputfiles=0,
  inputdatasets=0,
  inputparams=0,
  debug=log,
  mdebug=0,
  outlib=0,
  outref=0,
  viyaresult=WEBOUT_JSON,
  viyacontext=SAS Job Execution compute context
)/*/STORE SOURCE*/;

%mx_testservice(&program,
  inputfiles=&inputfiles,
  inputdatasets=&inputdatasets,
  inputparams=&inputparams,
  debug=&debug,
  mdebug=&mdebug,
  outlib=&outlib,
  outref=&outref,
  viyaresult=&viyaresult,
  viyacontext=&viyacontext
)

%mend mp_testservice;
