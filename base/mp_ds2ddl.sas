/**
  @file
  @brief A wrapper for mp_getddl.sas
  @details In the next release, this will be the main version.


  <h4> SAS Macros </h4>
  @li mp_getddl.sas

**/

%macro mp_ds2ddl(libds,fref=getddl,flavour=SAS,showlog=YES,schema=
  ,applydttm=NO
)/*/STORE SOURCE*/;

%local libref;
%let libds=%upcase(&libds);
%let libref=%scan(&libds,1,.);
%if &libref=&libds %then %let libds=WORK.&libds;

%mp_getddl(%scan(&libds,1,.)
  ,%scan(&libds,2,.)
  ,fref=&fref
  ,flavour=SAS
  ,showlog=&showlog
  ,schema=&schema
  ,applydttm=&applydttm
)

%mend mp_ds2ddl;