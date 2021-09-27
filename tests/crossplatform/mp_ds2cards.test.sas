/**
  @file
  @brief Testing mp_ds2cards.sas macro

  <h4> SAS Macros </h4>
  @li mp_ds2cards.sas
  @li mp_assert.sas

**/

/**
  * test 1 - rebuild an existing dataset
  * Cars is a great dataset - it contains leading spaces, and formatted numerics
  */

%mp_ds2cards(base_ds=sashelp.cars
  , tgt_ds=work.test
  , cards_file= "%sysfunc(pathname(work))/cars.sas"
  , showlog=NO
)
%inc "%sysfunc(pathname(work))/cars.sas"/source2;

proc compare base=sashelp.cars compare=work.test;
quit;

%mp_assert(
  iftrue=(&sysinfo=1),
  desc=sashelp.cars is identical except for ds label,
  outds=work.test_results
)

/**
  * test 2 - binary data compare
  */
data work.binarybase;
  format bin $hex500. z $hex.;
  do x=1 to 250;
    z=byte(x);
    bin=trim(bin)!!z;
    output;
  end;
run;

%mp_ds2cards(base_ds=work.binarybase
  , showlog=YES
  , cards_file="%sysfunc(pathname(work))/c2.sas"
  , tgt_ds=work.binarycompare
  , append=
)

%inc "%sysfunc(pathname(work))/c2.sas"/source2;

proc compare base=work.binarybase compare=work.binarycompare;
run;

%mp_assert(
  iftrue=(&sysinfo=0),
  desc=work.binarybase dataset is identical,
  outds=work.test_results
)