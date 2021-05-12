/**
  @file
  @brief Testing mp_abort macro
  @details This is an unfixed problem with mp_abort when using the
  'unclosed macro' technique.  This is only relevant for 9.4m3 environments,
  which can suffer from hung multibridge sessions from %abort and endsas.

  The issue is that when called within a macro, within a %include, AND that
  macro contains subsequent logic, the service does not end cleanly - rather,
  we see:

      ERROR: %EVAL function has no expression to evaluate, or %IF statement has no condition.
      ERROR: The macro TEST will stop executing.

  We are not able to test this without a 9.4m3 environment, it is marked as
  nofix.

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mp_assert.sas

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