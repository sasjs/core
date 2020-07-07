/**
  @file
  @brief Returns the engine type of a SAS library
  @details Usage:

      %put %mf_getEngine(SASHELP);

  returns:
  > V9

  A note is also written to the log.  The credit for this macro goes to the
  contributors of Chris Hemedingers blog [post](
  http://blogs.sas.com/content/sasdummy/2013/06/04/find-a-sas-library-engine/)

  @param libref Library reference (also accepts a 2 level libds ref).

  @return output returns the library engine for the FIRST library encountered.

  @warning will only return the FIRST library engine - for concatenated
    libraries, with different engines, inconsistent results may be encountered.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getEngine(libref
)/*/STORE SOURCE*/;
  %local dsid engnum rc engine;

  /* in case the parameter is a libref.tablename, pull off just the libref */
  %let libref = %upcase(%scan(&libref, 1, %str(.)));

  %let dsid=%sysfunc(open(sashelp.vlibnam(where=(libname="%upcase(&libref)")),i));
  %if (&dsid ^= 0) %then %do;
    %let engnum=%sysfunc(varnum(&dsid,ENGINE));
    %let rc=%sysfunc(fetch(&dsid));
    %let engine=%sysfunc(getvarc(&dsid,&engnum));
    %put &libref. ENGINE is &engine.;
    %let rc= %sysfunc(close(&dsid));
  %end;

 &engine

%mend;
