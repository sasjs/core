/**
  @file
  @brief Testing mp_stprequests macro

  <h4> SAS Macros </h4>
  @li mp_stprequests.sas
  @li mp_assert.sas

**/

/* the base table the macro appends to */
proc sql;
  create table work.stp_requests(
    request_dttm num not null format=datetime.
    ,status_cd char(4) not null
    ,_metaperson varchar(100) not null
    ,_program varchar(500)
    ,sysuserid varchar(50)
    ,sysjobid varchar(12)
    ,_sessionid varchar(50)
  );
quit;

%mp_stprequests(status_cd=INIT,libds=work.stp_requests)
%mp_stprequests(status_cd=TERM,libds=work.stp_requests)

proc sql noprint;
  select count(*) into: n_rows from work.stp_requests;
  select count(*) into: n_init from work.stp_requests where status_cd='INIT';
  select count(*) into: n_user from work.stp_requests where length(sysuserid)>0;
quit;

%mp_assert(
  iftrue=(&n_rows=2),
  desc=Checking that an INIT and a TERM row are both written,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_init=1),
  desc=Checking that the status code is carried onto the row,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_user=2),
  desc=Checking that the session account is recorded,
  outds=work.test_results
)
