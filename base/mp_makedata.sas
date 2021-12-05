/**
  @file
  @brief Create sample data based on the structure of an empty table
  @details Many SAS projects involve sensitive datasets.  One way to _ensure_
    the data is anonymised, is never to receive it in the first place!  Often
    consultants are provided with empty tables, and expected to create complex
    ETL flows.

    This macro can help by taking an empty table, and populating it with data
    according to the variable types and formats.

    The primary key is respected, as well as any NOT NULL constraints.

  Usage:

      proc sql;
      create table work.example(
        TX_FROM float format=datetime19.,
        DD_TYPE char(16),
        DD_SOURCE char(2048),
        DD_SHORTDESC char(256),
        constraint pk primary key(tx_from, dd_type,dd_source),
        constraint nnn not null(DD_SHORTDESC)
      );
      %mp_makedata(work.example)

  @param [in] libds The empty table in which to create data
  @param [out] obs= (500) The number of records to create.

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_getcols.sas
  @li mp_getpk.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_makedata(libds
  ,obs=500
)/*/STORE SOURCE*/;


%mend mp_makedata;