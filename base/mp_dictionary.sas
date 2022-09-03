/**
  @file mp_dictionary.sas
  @brief Creates a portal (libref) into the SQL Dictionary Views
  @details Provide a libref and the macro will create a series of views against
  each view in the special PROC SQL dictionary libref.

  This is useful if you would like to visualise (navigate) the views in a SAS
  client such as Base SAS, Enterprise Guide, or Studio (or [Data Controller](
  https://datacontroller.io)).

  It works by extracting the dictionary.dictionaries view into
  YOURLIB.dictionaries, then uses that to create a YOURLIB.{viewName} for every
  other dictionary.view, eg:

      proc sql;
      create view YOURLIB.columns as select * from dictionary.columns;

  Usage:

      libname demo "/lib/directory";
      %mp_dictionary(lib=demo)

  Or, to just create them in WORK:

      %mp_dictionary()

  If you'd just like to browse the dictionary data model, you can also check
  out [this article](https://rawsas.com/dictionary-of-dictionaries/).

  ![](https://user-images.githubusercontent.com/4420615/188278365-2987db97-0594-4a39-ac81-dbacdef5cdc8.png)

  @param lib= (WORK) The libref in which to create the views

  <h4> Related Files </h4>
  @li mp_dictionary.test.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_dictionary(lib=WORK)/*/STORE SOURCE*/;
  %local list i mem;
  proc sql noprint;
  create view &lib..dictionaries as select * from dictionary.dictionaries;
  select distinct memname into: list separated by ' '  from &lib..dictionaries;
  %do i=1 %to %sysfunc(countw(&list,%str( )));
    %let mem=%scan(&list,&i,%str( ));
    create view &lib..&mem as select * from dictionary.&mem;
  %end;
  quit;
%mend mp_dictionary;
