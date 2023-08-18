/**
  @file
  @brief Fetches DDL for a specific table
  @details Uses mp_getddl under the hood

  @param [in] libds library.dataset to create ddl for
  @param [in] fref= (getddl) the fileref to which to _append_ the DDL.  If it
    does not exist, it will be created.
  @param [in] flavour= (SAS) The type of DDL to create. Options:
    @li SAS
    @li TSQL

  @param [in]showlog= (NO) Set to YES to show the DDL in the log
  @param [in] schema= () Choose a preferred schema name (default is to use
    actual schema, else libref)
  @param applydttm= (NO) For non SAS DDL, choose if columns are created with
    native datetime2 format or regular decimal type

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