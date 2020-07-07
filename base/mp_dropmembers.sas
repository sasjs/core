/**
  @file
  @brief Drops tables / views (if they exist) without warnings in the log
  @details
  Example usage:

      proc sql;
      create table data1 as select * from sashelp.class;
      create view view2 as select * from sashelp.class;
      %mp_dropmembers(list=data1 view2)

  <h4> Dependencies </h4>
  @li mf_isblank.sas


  @param list space separated list of datasets / views
  @param libref= can only drop from a single library at a time

  @version 9.2
  @author Allan Bowe

**/

%macro mp_dropmembers(
     list /* space separated list of datasets / views */
    ,libref=WORK  /* can only drop from a single library at a time */
)/*/STORE SOURCE*/;

  %if %mf_isblank(&list) %then %do;
    %put NOTE: nothing to drop!;
    %return;
  %end;

  proc datasets lib=&libref nolist;
    delete &list;
    delete &list /mtype=view;
  run;
%mend;