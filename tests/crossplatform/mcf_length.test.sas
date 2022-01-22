/**
  @file
  @brief Testing mcf_length.sas macro

  <h4> SAS Macros </h4>
  @li mcf_length.sas
  @li mp_assert.sas

**/

%mcf_length(wrap=YES, insert_cmplib=YES)

data test;
  call symputx('null',mcf_length(.));
  call symputx('three',mcf_length(1));
  call symputx('four',mcf_length(10000000));
  call symputx('five',mcf_length(12345678));
  call symputx('six',mcf_length(1234567890));
  call symputx('seven',mcf_length(12345678901234));
  call symputx('eight',mcf_length(12345678901234567));
run;

%mp_assert(
  iftrue=(%str(&null)=%str(0)),
  desc=Check if NULL returns 0
)
%mp_assert(
  iftrue=(%str(&three)=%str(3)),
  desc=Check for length 3
)
%mp_assert(
  iftrue=(%str(&four)=%str(4)),
  desc=Check for length 4
)
%mp_assert(
  iftrue=(%str(&five)=%str(5)),
  desc=Check for length 5
)
%mp_assert(
  iftrue=(%str(&six)=%str(6)),
  desc=Check for length 6
)
%mp_assert(
  iftrue=(%str(&seven)=%str(7)),
  desc=Check for length 3
)
%mp_assert(
  iftrue=(%str(&eight)=%str(8)),
  desc=Check for length 8
)