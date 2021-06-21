/**
  @file mp_createconstraints.sas
  @brief Creates constraints
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
      %mp_createconstraints(inds=work.constraints,outds=created,execute=YES)

  @param inds= The input table containing the constraint info
  @param outds= a table containing the create statements (create_statement column)
  @param execute= `YES|NO` - default is NO. To actually create, use YES.

  <h4> SAS Macros </h4>

  @version 9.2
  @author Allan Bowe

**/

%macro mp_createconstraints(inds=mp_getconstraints
  ,outds=mp_createconstraints
  ,execute=NO
)/*/STORE SOURCE*/;

proc sort data=&inds out=&outds;
  by libref table_name constraint_name;
run;

data &outds;
  set &outds;
  by libref table_name constraint_name;
  length create_statement $500;
  if _n_=1 and "&execute"="YES" then call execute('proc sql;');
  if first.constraint_name then do;
    if constraint_type='PRIMARY' then type='PRIMARY KEY';
    else type=constraint_type;
    create_statement=catx(" ","alter table",libref,".",table_name
      ,"add constraint",constraint_name,type,"(");
    if last.constraint_name then
      create_statement=cats(create_statement,column_name,");");
    else create_statement=cats(create_statement,column_name,",");
    if "&execute"="YES" then call execute(create_statement);
  end;
  else if last.constraint_name then do;
    create_statement=cats(column_name,");");
    if "&execute"="YES" then call execute(create_statement);
  end;
  else do;
    create_statement=cats(column_name,",");
    if "&execute"="YES" then call execute(create_statement);
  end;
  output;
run;

%mend mp_createconstraints;