/**
  @file mv_getviyafileextparms.sas
  @brief Reads the VIYA file-extension type definition and returns selected
    values in SAS macro variables

  @details Content is derived from the following endpoint:
    "https://${serverUrl}/types/types?limit=999999"

  @param [in] ext File extension to retrieve property info for.
  @param [out] propertiesVar= SAS macro variable name that will contain
    the 'properties' object json, if found, else blank.
  @param [out] typeDefNameVar= SAS macro variable name that will contain
    the 'typeDefName' property value, if found, else blank.
  @param [out] mediaTypeVar= SAS macro variable name that will contain
    the 'mediaType' property value, if found, else blank.
  @param [out] viyaFileExtRespLibDs (work.mv_getViyaFileExtParmsResponse)
    Library.name of the dataset to receive the local working copy of the initial
    response that requests all file extension details. Created once per session
    to avoid multiple api calls.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_getvalue.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas
  @li mf_isblank.sas
  @li mf_nobs.sas
  @li mp_abort.sas

**/

%macro mv_getViyaFileExtParms(
  ext,
  typeDefNameVar=,
  propertiesVar=,
  mediaTypeVar=,
  viyaFileExtRespLibDs=work.mv_getViyaFileExtParmsResponse,
  mdebug=0
  );
  %local base_uri; /* location of rest apis */
  %local url; /* File extension info end-point */

  %mp_abort(
    iftrue=(%mf_isBlank(&ext))
    ,msg=%str(No file extension provided.)
    ,mac=MV_GETVIYAFILEEXTPARMS
  );

  %mp_abort(
    iftrue=(%mf_isBlank(&typeDefNameVar) and
            %mf_isBlank(&propertiesVar) and
            %mf_isBlank(&mediaTypeVar))
    ,msg=%str(MV_GETVIYAFILEEXTPARMS - No parameter was requested.)
    ,mac=MV_GETVIYAFILEEXTPARMS
  );

  %mp_abort(
    iftrue=(%mf_isBlank(&viyaFileExtRespLibDs))
    ,msg=%str(No <libname.>dataset name provided to cache inital response.)
    ,mac=MV_GETVIYAFILEEXTPARMS
  );

  /* Declare requested parameters as global macro vars and initialize blank */
  %if not %mf_isBlank(&typeDefNameVar) %then %do;
    %global &typeDefNameVar;
    %let &typeDefNameVar = %str();
  %end;
  %if not %mf_isBlank(&propertiesVar) %then %do;
    %global &propertiesVar;
    %let &propertiesVar = %str();
  %end;
  %if not %mf_isBlank(&mediaTypeVar) %then %do;
    %global &mediaTypeVar;
    %let &mediaTypeVar = %str();
  %end;

  %let base_uri=%mf_getplatform(VIYARESTAPI);
  %if &mdebug=1 %then %do;
    %put DEBUG: &=base_uri;
  %end;

  %let ext=%lowcase(&ext);

  /* Create a local copy of the Viya response containing all file type info, if
  it does not already exist. */
  %if not %mf_existds(&viyaFileExtRespLibDs) %then %do;
    /* Create a temp file and fill with JSON that declares */
    /* VIYA file-type details for the given file extension */
    %local viyatypedefs;
    %let viyatypedefs=%mf_getuniquefileref();
    filename &viyatypedefs temp;

    %let url = &base_uri/types/types?limit=999999;

    proc http oauth_bearer=sas_services out=&viyatypedefs
      url="&url";
    run;

    %if &mdebug=1 %then %put DEBUG: &sysmacroname &=url
      &=SYS_PROCHTTP_STATUS_CODE &=SYS_PROCHTTP_STATUS_PHRASE;

    %if (&SYS_PROCHTTP_STATUS_CODE ne 200) %then %do;
      /* To avoid a breaking change, exit early if the request failed.
        The calling process will proceed with empty requested macro variables. */
      %put INFO: &sysmacroname File extension details were not retrieved.;
      filename &viyatypedefs clear;
      %return;
    %end;

    %if &mdebug=1 %then %do;
      /* Dump the response to the log */
      data _null_;
        length line $120;
        null=byte(0);
        infile &viyatypedefs dlm=null lrecl=120 recfm=n;
        input line $120.;
        if _n_ = 1 then put "DEBUG:";
        put line;
      run;
    %end;

    /* Convert the content of that JSON into SAS datasets */
      /* First prepare a new WORK-based folder to receive the datasets */
    %local jsonworkfolder jsonlib opt_dlcreatedir;
    %let jsonworkfolder=%sysfunc(pathname(work))/%mf_getuniquename(prefix=json_);
    %let jsonlib=%mf_getuniquelibref(prefix=json);
      /* And point a libname at it */
    %let opt_dlcreatedir = %sysfunc(getoption(dlcreatedir));
    options dlcreatedir; libname &jsonlib "&jsonworkfolder"; options &opt_dlcreatedir;

    /* Read the json output once and copy datasets to its work folder */
    %local libref1;
    %let libref1=%mf_getuniquelibref();
    libname &libref1 JSON fileref=&viyatypedefs automap=create;
    proc copy in=&libref1 out=&jsonlib; run;

    libname &libref1 clear;

    /* Now give all rows belonging to the same items array a grouping value */
    data &viyaFileExtRespLibDs;
      length _viyaItemIdx 8;
      set &jsonlib..alldata;
      retain _viyaItemIdx 0;
      /* Increment the row group index when a new 'items' group is observed */
      if P=1 and P1='items' then _viyaItemIdx + 1;
    run;

    %if &mdebug=0 %then %do;
      /* Tidy up, unless debug=1 */
      proc datasets library=&jsonlib nolist kill; quit;
      libname &jsonlib clear;
    %end;

    filename &viyatypedefs clear;

  %end; /* If initial filetype query response didn't exist */

  /* Find the row-group for the current file extension */
  %local itemRowGroup;
  %let itemRowGroup =
    %mf_getValue(
      &viyaFileExtRespLibDs
      ,_viyaItemIdx
      ,filter=%quote(p1='items' and p2='extensions' and value="&ext")
    );

  %if &mdebug %then %put DEBUG: &=itemRowGroup;

  %if %mf_isBlank(&itemRowGroup) %then %do;
    /* extension was not found */
    %if(&mdebug=1) %then %put DEBUG: No type details found for extension "&ext".;
    %return;
  %end;

  /* Filter the cached response data down to the required file extension */
  %local dsItems;
  %let dsItems = %mf_getuniquename(prefix=dsItems_);
  data work.&dsItems;
    set &viyaFileExtRespLibDs;
    where _viyaItemIdx = &itemRowGroup;
  run;

  /* Populate typeDefName, if requested */
  %if (not %mf_isBlank(&typeDefNameVar)) %then %do;
    %let &typeDefNameVar = %mf_getvalue(&dsItems,value,filter=%quote(p1="items" and p2="name"));
    %if &mdebug=1 %then %put DEBUG: &=typeDefNameVar &typeDefNameVar=&&&typeDefNameVar;
  %end;

  /* Populate mediaType, if requested */
  %if (not %mf_isBlank(&mediaTypeVar)) %then %do;
    %let &mediaTypeVar = %mf_getvalue(&dsItems,value,filter=%quote(p1="items" and p2="mediaType"));
    %if &mdebug=1 %then %put DEBUG: &=mediaTypeVar &mediaTypeVar=&&&mediaTypeVar;
  %end;

  /* Populate properties macro variable, if requested */
  %if not %mf_isBlank(&propertiesVar) %then %do;

    /* Filter dsItems down to the properties */
    %local dsProperties;
    %let dsProperties = %mf_getuniquename(prefix=dsProperties_);
    data work.&dsProperties ( rename=(p3 = propertyName) );
        set work.&dsItems;
        where p2="properties" and v=1;
    run;

    /* Check for 1+ properties */
    %if ( %mf_nobs(&dsProperties) = 0 ) %then %do;
      %let &propertiesVar = %str();
      %if &mdebug=1 %then %put DEBUG: &SYSMACRONAME - No Viya properties found for file suffix %str(%')&ext%str(%');
    %end;
    %else %do;
      /* Properties potentially span multiple rows in the input table */
      data _null_;
        length
          line $32767
          properties $32767
        ;
        retain properties;
        set &dsProperties end=last;
        if _n_ = 1 then properties = '{';

        line = cats(quote(trim(propertyName)),':');
        /* Only strings and bools appear in properties */
        if value not in ("true","false") then value = quote(trim(value));
        line = catx(' ',line,value);
        /* Add a comma separator to all except the last line */
        if not last then line = cats(line,',');

        /* Add this line to the output value */
        properties = catx(' ',properties,line);

        if last then do;
          /* Close off the properties object and output to the macro variable */
          properties=catx(' ',properties,'}');
          call symputx("&propertiesVar",properties);
        end;
      run;

      %if &mdebug=1 %then %put DEBUG: &=propertiesVar &propertiesVar=&&&propertiesVar;
    %end;

  %end;

%mend mv_getViyaFileExtParms;
