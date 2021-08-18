/**
  @file
  @brief Testing mf_getapploc macro

  <h4> SAS Macros </h4>
  @li mf_getapploc.sas
  @li mp_assert.sas

**/

%mp_assert(
  iftrue=(
    "%mf_getapploc(/some/loc/tests/services/x/service)"="/some/loc"
  ),
  desc=Checking test appLoc matches,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_getapploc(/some/loc/tests/services/tests/service)"="/some/loc"
  ),
  desc=Checking nested services appLoc matches,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_getapploc(/some/area/services/admin/service)"="/some/area"
  ),
  desc=Checking services appLoc matches,
  outds=work.test_results
)

%mp_assert(
  iftrue=(
    "%mf_getapploc(/some/area/jobs/jobs/job)"="/some/area"
  ),
  desc=Checking jobs appLoc matches,
  outds=work.test_results
)