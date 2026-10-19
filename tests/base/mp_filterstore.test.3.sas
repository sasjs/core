/**
  @file
  @brief Testing mp_filterstore macro with a separate validation target

  @details A filter may reference a variable that only exists in a view - for
  example a computed column.  In that case the validation target differs from
  the table the filter is stored against.

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas
  @li mddl_dc_filterdetail.sas
  @li mddl_dc_filtersummary.sas
  @li mddl_dc_locktable.sas
  @li mddl_dc_maxkeytable.sas
  @li mp_filterstore.sas

**/

libname permlib (work);

%mddl_dc_locktable(libds=permlib.locktable)
%mddl_dc_filtersummary(libds=permlib.filtsum)
%mddl_dc_filterdetail(libds=permlib.filtdet)
%mddl_dc_maxkeytable(libds=permlib.maxkey)

data work.class;
  set sashelp.class;
run;

/* a view that adds a computed column */
data work.vw_class / view=work.vw_class;
  set work.class;
  length band $8;
  if age>13 then band='TEEN';
  else band='JUNIOR';
run;

/* valid filter - references the computed column */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$12. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,BAND,=,"'TEEN'"
AND,AND,1,SEX,=,"'M'"
;;;;
run;

%mp_assertscope(SNAPSHOT)
%mp_filterstore(libds=work.class,
  targetds=work.vw_class,
  queryds=work.inds,
  filter_summary=permlib.filtsum,
  filter_detail=permlib.filtdet,
  lock_table=permlib.locktable,
  maxkeytable=permlib.maxkey,
  outresult=work.result,
  outquery=work.query,
  mdebug=1
)
%mp_assertscope(COMPARE)

%mp_assert(iftrue=(&syscc=0),
  desc=Ensure macro runs without errors,
  outds=work.test_results
)
/* ensure only one record created */
%mp_assertdsobs(permlib.filtsum,
  desc=Initial query creates exactly one summary record,
  test=EQUALS 1,
  outds=work.test_results
)
/* the filter must still be stored against the physical table */
data work.chk;
  set permlib.filtsum;
  where filter_table='WORK.CLASS';
run;
%mp_assertdsobs(work.chk,
  desc=Filter table is the physical table, not the validation target,
  test=EQUALS 1,
  outds=work.test_results
)
