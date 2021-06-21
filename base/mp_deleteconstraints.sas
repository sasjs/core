/**
  @file mp_deleteconstraints.sas
  @brief Delete constraionts
  @details Takes the output from mp_getconstraints.sas as input

        proc sql;
        create table work.example(
          TX_FROM float format=datetime19.,
          DD_TYPE char(16),
          DD_SOURCE char(2048),
          DD_SHORTDESC char(256),
          constraint pk primary key(tx_from, dd_type,dd_source),
          constraint unq unique(tx_from, dd_type),
          constraint nnn not null(DD_SHORTDESC)
        );

      %mp_getconstraints(lib=work,ds=example,outds=work.constraints)
      %mp_deleteconstraints(inds=work.constraints,outds=dropped,execute=YES)

  @param inds= The input table containing the constraint info
  @param outds= a table containing the drop statements (drop_statement column)
  @param execute= `YES|NO` - default is NO. To actually drop, use YES.


  @version 9.2
  @author Allan Bowe

**/

%macro mp_deleteconstraints(inds=mp_getconstraints
  ,outds=mp_deleteconstraints
  ,execute=NO
)/*/STORE SOURCE*/;

proc sort data=&inds out=&outds;
  by libref table_name constraint_name;
run;

data &outds;
  set &outds;
  by libref table_name constraint_name;
  length drop_statement $500;
  if _n_=1 and "&execute"="YES" then call execute('proc sql;');
  if first.constraint_name then do;
    drop_statement=catx(" ","alter table",libref,".",table_name
      ,"drop constraint",constraint_name,";");
    output;
    if "&execute"="YES" then call execute(drop_statement);
  end;
run;

%mend mp_deleteconstraints;