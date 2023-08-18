/**
  @file mfv_existsashdat.sas
  @brief Checks whether a CAS sashdat dataset exists in persistent storage.
  @details Can be used in open code, eg as follows:

      %if %mfv_existsashdat(libds=casuser.sometable) %then %put  yes it does!;

  The function uses `dosubl()` to run the `table.fileinfo` action, for the
  specified library, filtering for `*.sashdat` tables.  The results are stored
  in a WORK table (&outprefix._&lib). If that table already exists, it is
  queried instead, to avoid the dosubl() performance hit.

  To force a rescan, just use a new `&outprefix` value, or delete the table(s)
  before running the function.

  @param [in] libds library.dataset
  @param [out] outprefix= (work.mfv_existsashdat)
    Used to store current HDATA tables to improve subsequent query performance.
    This reference is a prefix and is converted to `&prefix._{libref}`

  @return output returns 1 or 0

  @version 0.2
  @author Mathieu Blauw
**/

%macro mfv_existsashdat(libds,outprefix=work.mfv_existsashdat
);
%local rc dsid name lib ds;
%let lib=%upcase(%scan(&libds,1,'.'));
%let ds=%upcase(%scan(&libds,-1,'.'));

/* if table does not exist, create it */
%if %sysfunc(exist(&outprefix._&lib)) ne 1 %then %do;
  %let rc=%sysfunc(dosubl(%nrstr(
    /* Read in table list (once per &lib per session) */
    proc cas;
      table.fileinfo result=source_list /caslib="&lib";
      val=findtable(source_list);
      saveresult val dataout=&outprefix._&lib;
    quit;
    /* Only keep name, without file extension */
    data &outprefix._&lib;
      set &outprefix._&lib(where=(Name like '%.sashdat') keep=Name);
      Name=upcase(scan(Name,1,'.'));
    run;
  )));
%end;

/* Scan table for hdat existence */
%let dsid=%sysfunc(open(&outprefix._&lib(where=(name="&ds"))));
%syscall set(dsid);
%let rc = %sysfunc(fetch(&dsid));
%let rc = %sysfunc(close(&dsid));

/* Return result */
%if "%trim(&name)"="%trim(&ds)" %then 1;
%else 0;

%mend mfv_existsashdat;
