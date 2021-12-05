/**
  @file
  @brief Drops tables / views (if they exist) without warnings in the log
  @details Useful for dropping tables when you're not sure they exist, or if
  you are not sure whether they are a dataset or view.  Also efficient for
  dropping multiple tables / views.

  Example usage:

      proc sql;
      create table data1 as select * from sashelp.class;
      create view view2 as select * from sashelp.class;
      %mp_dropmembers(data1 view2, libref=WORK)


  <h4> SAS Macros </h4>
  @li mf_isblank.sas


  @param [in] list space separated list of datasets / views, WITHOUT libref
  @param [in] libref= (WORK) Note - you can only drop from one library at a time
  @param [in] iftrue= (1=1) Conditionally drop tables, eg if &debug=N

  @version 9.2
  @author Allan Bowe

**/

%macro mp_dropmembers(
    list /* space separated list of datasets / views */
    ,libref=WORK  /* can only drop from a single library at a time */
    ,iftrue=%str(1=1)
)/*/STORE SOURCE*/;

  %if not(%eval(%unquote(&iftrue))) %then %return;

  %if %mf_isblank(&list) %then %do;
    %put NOTE: nothing to drop!;
    %return;
  %end;

  proc datasets lib=&libref nolist;
    delete &list;
    delete &list /mtype=view;
  run;
%mend mp_dropmembers;