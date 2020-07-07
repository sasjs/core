/**
  @file
  @brief Creates a dataset containing distinct _formatted_ values
  @details If no format is supplied, then the original value is used instead.
    There is also a dependency on other macros within the Macro Core library.
    Usage:

        %mp_distinctfmtvalues(libds=sashelp.class,var=age,outvar=age,outds=test)

  @param libds input dataset
  @param var variable to get distinct values for
  @param outvar variable to create.  Default:  `formatted_value`
  @param outds dataset to create.  Default:  work.mp_distinctfmtvalues
  @param varlen length of variable to create (default 200)

  @version 9.2
  @author Allan Bowe

**/

%macro mp_distinctfmtvalues(
     libds=
    ,var=
    ,outvar=formatted_value
    ,outds=work.mp_distinctfmtvalues
    ,varlen=2000
)/*/STORE SOURCE*/;

  %local fmt vtype;
  %let fmt=%mf_getvarformat(&libds,&var);
  %let vtype=%mf_getvartype(&libds,&var);

  proc sql;
  create table &outds as
    select distinct
    %if &vtype=C & %trim(&fmt)=%str() %then %do;
       &var
    %end;
    %else %if &vtype=C %then %do;
      put(&var,&fmt)
    %end;
    %else %if %trim(&fmt)=%str() %then %do;
        put(&var,32.)
    %end;
    %else %do;
      put(&var,&fmt)
    %end;
       as &outvar length=&varlen
    from &libds;
%mend;