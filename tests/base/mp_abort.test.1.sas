/**
  @file
  @brief Testing mp_abort macro
  @details This is an unfixed problem with mp_abort.  When called from within
  a macro, within a %include, and that macro contains subsequent logic, the
  service does not end cleanly - rather, we see:

      ERROR: %EVAL function has no expression to evaluate, or %IF statement has no condition.
      ERROR: The macro TEST will stop executing.

  <h4> SAS Macros </h4>
  @li mp_abort.sas

**/

%macro test();

filename blah temp;
data _null_;
  file blah;
  put '%mp_abort();';
run;
%inc blah;

%if 1=1 %then %put Houston - we have a problem here;
%mend test;

%test()