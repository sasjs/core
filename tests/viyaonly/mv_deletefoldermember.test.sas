/**
  @file
  @brief Testing mv_deletefoldermember macro

  <h4> SAS Macros </h4>
  @li mfv_existfile.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_createfile.sas
  @li mv_deletefoldermember.sas

**/

%let folder=&mcTestAppLoc/temp;
%let name=deleteme.txt;

filename somefile temp;
data _null_;
  file somefile;
  put 'delete me';
run;
%mv_createfile(path=&folder, name=&name, inref=somefile)

%mp_assert(
  iftrue=(%mfv_existfile(&folder/&name)=1),
  desc=Check the file exists before the delete
)

/* the JSON libname engine publishes five globals per libref when it parses a
  REST response, and the libref numbers are fixed because each test runs in a
  fresh session.  They are listed so the comparison covers the macro's own
  variables. */
%mp_assertscope(SNAPSHOT)
%mv_deletefoldermember(path=&folder, name=&name, contenttype=file)
%mp_assertscope(COMPARE,
  desc=mv_deletefoldermember does not leak scope,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN
    MC1_JADP1LEN MC1_JADP2LEN MC1_JADP3LEN MC1_JADPNUM MC1_JADVLEN
    MC2_JADP1LEN MC2_JADP2LEN MC2_JADP3LEN MC2_JADPNUM MC2_JADVLEN,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mfv_existfile(&folder/&name)=0),
  desc=Check the file is gone after the delete
)
