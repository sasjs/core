/**
  @file
  @brief Returns all children from a hierarchy table for a specified parent
  @details Where data stores hierarchies in a simple parent / child mapping,
    it is not always straightforward to extract all the children for a
    particular parent.  This problem is known as a recursive self join.  This
    macro will extract all the descendents for a parent.
  Usage:

      data have;
        p=1;c=2;output;
        p=2;c=3;output;
        p=2;c=4;output;
        p=3;c=5;output;
        p=6;c=7;output;
        p=8;c=9;output;
      run;

      %mp_recursivejoin(base_ds=have
        ,outds=want
        ,matchval=1
        ,parentvar=p
        ,childvar=c
        )

  @param base_ds= base table containing hierarchy (not modified)
  @param outds= the output dataset to create with the generated hierarchy
  @param matchval= the ultimate parent from which to filter
  @param parentvar= name of the parent variable
  @param childvar= name of the child variable (should be same type as parent)
  @param mdebug= set to 1 to prevent temp tables being dropped


  @returns outds contains the following variables:
   - level (0 = top level)
   - &parentvar
   - &childvar (null if none found)

  @version 9.2
  @author Allan Bowe

**/

%macro mp_recursivejoin(base_ds=
    ,outds=
    ,matchval=
    ,parentvar=
    ,childvar=
    ,iter= /* reserved for internal / recursive use by the macro itself */
    ,maxiter=500 /* avoid infinite loop */
    ,mDebug=0);

%if &iter= %then %do;
  proc sql;
  create table &outds as
    select 0 as level,&parentvar, &childvar
    from &base_ds
    where &parentvar=&matchval;
  %if &sqlobs.=0 %then %do;
    %put NOTE: &sysmacroname: No match for &parentvar=&matchval;
    %return;
  %end;
  %let iter=1;
%end;
%else %if &iter>&maxiter %then %return;

proc sql;
create table _data_ as
  select &iter as level
    ,curr.&childvar as &parentvar
    ,base_ds.&childvar as &childvar
  from &outds curr
  left join &base_ds base_ds
  on  curr.&childvar=base_ds.&parentvar
  where curr.level=%eval(&iter.-1)
    & curr.&childvar is not null;
%local append_ds; %let append_ds=&syslast;
%local obs; %let obs=&sqlobs;
insert into &outds select distinct * from &append_ds;
%if &mdebug=0 %then drop table &append_ds;;

%if &obs %then %do;
  %mp_recursivejoin(iter=%eval(&iter.+1)
    ,outds=&outds,parentvar=&parentvar
    ,childvar=&childvar
    ,base_ds=&base_ds
    )
%end;

%mend;
