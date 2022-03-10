/**
  @file
  @brief Testing mm_webout macro

  <h4> SAS Macros </h4>
  @li mm_spkexport.sas
  @li mp_assert.sas
  @li mp_as

**/


%* create sample text file as input to the macro;
filename tmp temp;
data _null_;
  file tmp;
  put '%let mmxuser="sasdemo";';
  put '%let mmxpass="Mars321";';
run;

filename myref "%sysfunc(pathname(work))/mmxexport.sh"
  permission='A::u::rwx,A::g::r-x,A::o::---';
%mp_assertscope(SNAPSHOT)
%mm_spkexport(metaloc=%str(/Shared Data)
    ,outref=myref
    ,secureref=tmp
    ,cmdoutloc=%str(/tmp)
)
%mp_assertscope(COMPARE)

data _null_;
  infile tmp;
  input;
  putlog _infile_;
  call symputx('nobs',_n_);
run;

%mp_assert(
  iftrue=(&nobs>2),
  desc=Check if content was created
)
