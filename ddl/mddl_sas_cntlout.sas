/**
  @file
  @brief The CNTLOUT table generated by proc format
  @details This table will actually change format depending on the data values,
  therefore the max possible lengths are described here to enable consistency
  when dealing with format data.

**/


%macro mddl_sas_cntlout(libds=WORK.CNTLOUT);

proc sql;
create table &libds(
    FMTNAME char(32)      label='Format name'
    /*
      to accommodate larger START values, mp_loadformat.sas will need the
      SQL dependency removed (proc sql needs to accommodate 3 index values in
      a 32767 ibufsize limit)
    */
    ,START char(10000)    label='Starting value for format'
    ,END char(32767)      label='Ending value for format'
    ,LABEL char(32767)    label='Format value label'
    ,MIN num length=3     label='Minimum length'
    ,MAX num length=3     label='Maximum length'
    ,DEFAULT num length=3 label='Default length'
    ,LENGTH num length=3  label='Format length'
    ,FUZZ num             label='Fuzz value'
    ,PREFIX char(2)       label='Prefix characters'
    ,MULT num             label='Multiplier'
    ,FILL char(1)         label='Fill character'
    ,NOEDIT num length=3  label='Is picture string noedit?'
    ,TYPE char(1)         label='Type of format'
    ,SEXCL char(1)        label='Start exclusion'
    ,EEXCL char(1)        label='End exclusion'
    ,HLO char(13)         label='Additional information'
    ,DECSEP char(1)       label='Decimal separator'
    ,DIG3SEP char(1)      label='Three-digit separator'
    ,DATATYPE char(8)     label='Date/time/datetime?'
    ,LANGUAGE char(8)     label='Language for date strings'
);

%mend mddl_sas_cntlout;