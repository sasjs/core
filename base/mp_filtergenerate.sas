/**
  @file
  @brief Generates a filter clause from an input table, to a fileref
  @details Uses the input table to generate an output filter clause.
  This feature is used to create dynamic dropdowns in [Data Controller for SAS&reg](
  https://datacontroller.io). The input table should be in the format below:

  |GROUP_LOGIC:$3|SUBGROUP_LOGIC:$3|SUBGROUP_ID:8.|VARIABLE_NM:$32|OPERATOR_NM:$10|RAW_VALUE:$4000|
  |---|---|---|---|---|---|
  |AND|AND|1|AGE|=|12|
  |AND|AND|1|SEX|<=|'M'|
  |AND|OR|2|Name|NOT IN|('Jane','Alfred')|
  |AND|OR|2|Weight|>=|7|

  Note - if the above table is received from an external client, the values
  should first be validated using the mp_filtercheck.sas macro to avoid risk
  of SQL injection.

  To generate the filter, run the following code:

      data work.filtertable;
        infile datalines4 dsd;
        input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
          OPERATOR_NM:$10. RAW_VALUE:$4000.;
      datalines4;
      AND,AND,1,AGE,=,12
      AND,AND,1,SEX,<=,"'M'"
      AND,OR,2,Name,NOT IN,"('Jane','Alfred')"
      AND,OR,2,Weight,>=,7
      ;;;;
      run;

      %mp_filtergenerate(work.filtertable,outref=myfilter)

      data _null_;
        infile myfilter;
        input;
        put _infile_;
      run;

  Will write the following query to the log:

  > (
  >     AGE = 12
  >   AND
  >     SEX <= 'M'
  > ) AND (
  >     Name NOT IN ('Jane','Alfred')
  >   OR
  >     Weight >= 7
  > )

  @param [in] inds The input table with query values
  @param [out] outref= The output fileref to contain the filter clause.  Will
    be created (or replaced).

  <h4> Related Macros </h4>
  @li mp_filtercheck.sas
  @li mp_filtervalidate.sas

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_nobs.sas

  @version 9.3
  @author Allan Bowe

**/

%macro mp_filtergenerate(inds,outref=filter);

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc - on macro entry)
)

filename &outref temp;

%if %mf_nobs(&inds)=0 %then %do;
  /* ensure we have a default filter */
  data _null_;
    file &outref;
    put '1=1';
  run;
%end;
%else %do;
  data _null_;
    file &outref lrecl=32800;
    set &inds end=last;
    by SUBGROUP_ID;
    if _n_=1 then put '((';
    else if first.SUBGROUP_ID then put +1 GROUP_LOGIC '(';
    else put +2 SUBGROUP_LOGIC;

    put +4 VARIABLE_NM OPERATOR_NM RAW_VALUE;

    if last.SUBGROUP_ID then put ')'@;
    if last then put ')';
  run;
%end;

%mend mp_filtergenerate;
