/**
  @file mf_getschema.sas
  @brief Returns the database schema of a SAS library
  @details Usage:

      %put %mf_getschema(MYDB);

  returns:
  > dbo

  @param libref Library reference (also accepts a 2 level libds ref).

  @return output returns the library schema for the FIRST library encountered

  @warning will only return the FIRST library schema - for concatenated
    libraries, with different schemas, inconsistent results may be encountered.

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mf_getschema(libref
)/*/STORE SOURCE*/;
  %local dsid vnum rc schema;
  /* in case the parameter is a libref.tablename, pull off just the libref */
  %let libref = %upcase(%scan(&libref, 1, %str(.)));
  %let dsid=%sysfunc(open(sashelp.vlibnam(where=(
    libname="%upcase(&libref)" and sysname='Schema/Owner'
  )),i));
  %if (&dsid ^= 0) %then %do;
    %let vnum=%sysfunc(varnum(&dsid,SYSVALUE));
    %let rc=%sysfunc(fetch(&dsid));
    %let schema=%sysfunc(getvarc(&dsid,&vnum));
    %put &libref. schema is &schema.;
    %let rc= %sysfunc(close(&dsid));
  %end;

  &schema

%mend;

/** @endcond */
