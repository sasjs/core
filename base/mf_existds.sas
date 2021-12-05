/**
  @file mf_existds.sas
  @brief Checks whether a dataset OR a view exists.
  @details Can be used in open code, eg as follows:

      %if %mf_existds(libds=work.someview) %then %put  yes it does!;

  NOTE - some databases have case sensitive tables, for instance POSTGRES
    with the preserve_tab_names=yes libname setting.  This may impact
    expected results (depending on whether you 'expect' the result to be
    case insensitive in this context!)

  @param libds library.dataset
  @return output returns 1 or 0

  <h4> Related Macros </h4>
  @li mf_existds.test.sas

  @warning Untested on tables registered in metadata but not physically present
  @version 9.2
  @author Allan Bowe
**/

%macro mf_existds(libds
)/*/STORE SOURCE*/;

  %if %sysfunc(exist(&libds)) ne 1 & %sysfunc(exist(&libds,VIEW)) ne 1 %then 0;
  %else 1;

%mend mf_existds;
