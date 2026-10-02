/**
  @file
  @brief Retrieves a value from a dataset. Returned value is fetched from the
  'fetchobs=' record (row 1 by default), after applying the optional filter.
  Returns a vartype-specific missing value if no row is returned.

  @details Be sure to <code>%quote()</code> your where clause.  Example usage:

      %put %mf_getvalue(sashelp.class,name,filter=%quote(age=15));
      %put %mf_getvalue(sashelp.class,name);

  <h4> SAS Macros </h4>
  @li mf_getvartype.sas

  <h4> Related Macros </h4>
  @li mp_setkeyvalue.sas

  @param [in] libds dataset to query
  @param [in] variable the variable which contains the value to return.
  @param [in] filter= (1) contents of where clause
  @param [in] fetchobs= (1) observation to fetch. NB: Filter applies first.
  @param [in] warn= (0) Set to 1 to raise a w@rning log message on attempt to
                read past end of the input dataset.


  @version 9.2
  @author Allan Bowe
**/

%macro mf_getvalue(libds,variable,filter=1,fetchobs=1,warn=0
)/*/STORE SOURCE*/;
  %local dsid rc vartype;

  %let vartype = %mf_getvartype(&libds,&variable);

  %let dsid=%sysfunc(open(&libds(where=(&filter))));
  %if (&dsid) %then %do;
    %syscall set(dsid);
    %let rc = %sysfunc(fetchobs(&dsid,&fetchobs));
    %if (&rc ne 0) %then %do;
      %put %sysfunc(sysmsg());
      /* Set the requested variable to a missing value */
      /* Need only consider numerics - char variables are already empty*/
      %if (&vartype eq N) %then %let &variable = .;
      %if (&warn) %then %do;
        %if (&rc eq -1) %then %do; /* read past end of data */
          %put %sysfunc(
            compbl(
              %quote(WARN%str(ING): Missing value returned as no rows were)
              %quote(found in &libds for filter (%superq(filter)))
              %quote(and/or fetchobs (&fetchobs).)
            )
          );
          %let rc=4;
        %end;
      %end;
      /* And update SYSCC if the &rc value is higher */
      %let syscc = %sysfunc(max(&syscc,&rc));
    %end;
    %let rc = %sysfunc(close(&dsid));

    %trim(&&&variable)

  %end;
  %else %do;
    %put %sysfunc(sysmsg());
    %let syscc = %sysfunc(max(&syscc,%sysfunc(sysrc())));
  %end;

%mend mf_getvalue;
