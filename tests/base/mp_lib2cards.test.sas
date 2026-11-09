/**
  @file
  @brief Testing mp_lib2cards macro

  <h4> SAS Macros </h4>
  @li mp_lib2cards.sas
  @li mf_mkdir.sas
  @li mp_assert.sas

**/

%let root=%sysfunc(pathname(work))/lib2cards;
%mf_mkdir(&root/lib)
libname mclib "&root/lib";

data mclib.one;
  length lbl $20;
  lbl='cards_value';
run;

%mp_lib2cards(lib=mclib,outloc=&root/out,outfile=all_cards.sas)

%let cards=%sysfunc(pathname(work))/lib2cards/out/all_cards.sas;

%mp_assert(
  iftrue=(%sysfunc(fileexist(&cards))=1),
  desc=Checking that a single output file is created when outfile is given,
  outds=work.test_results
)

%let found=0;

data _null_;
  infile "&cards" truncover;
  input;
  if index(_infile_,'cards_value')>0 then call symputx('found',1,'g');
run;

%mp_assert(
  iftrue=(&found=1),
  desc=Checking that the table content reaches the cards file,
  outds=work.test_results
)
