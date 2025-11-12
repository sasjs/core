/**
  @file mv_getviyafileextparms.sas
  @brief Reads the VIYA file-extension type definition and returns selected
    values in SAS macro variables

  @details Content is derived from the following endpoint:
    "https://<srv>/types/types?filter=contains(extensions,'<some ext>')"

  @param [in] ext File extension to retrieve property info for.
  @param [out] propertiesVar= SAS macro variable name that will contain
    the 'properties' object json, if found, else blank.
  @param [out] typeDefNameVar= SAS macro variable name that will contain
    the 'typeDefName' property value, if found, else blank.
  @param [out] mediaTypeVar= SAS macro variable name that will contain
    the 'mediaType' property value, if found, else blank.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> SAS Macros </h4>
  @li mf_abort.sas
  @li mf_existds.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mf_getvalue.sas
  @li mf_getvarlist.sas
  @li mf_getvartype.sas

*/

%macro mv_getViyaFileExtParms(ext,typeDefNameVar=,propertiesVar=,mediaTypeVar=,mdebug=0);
  %local base_uri; /* location of rest apis */
  %local viyatypedef; /* temp fileref to json response */
  %local url; /* File extension info end-point */

  %mf_abort(iftrue=(%mf_isBlank(&ext))
    ,msg=%str(MV_GETVIYAFILEEXTPARMS - No file extension provided.)
  );

  %mf_abort(iftrue=(%mf_isBlank(&typeDefNameVar) and
                    %mf_isBlank(&propertiesVar) and
                    %mf_isBlank(&mediaTypeVar))
    ,msg=%str(MV_GETVIYAFILEEXTPARMS - No parameter was requested.)
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
    %put DEBUG: &SYSMACRONAME &=base_uri;
  %end;

  %let ext=%lowcase(&ext);

  /* Create a temp file and fill with JSON that declares */
  /* VIYA file-type details for the given file extension */
  %let viyatypedef=%mf_getuniquefileref();
  filename &viyatypedef temp;

  %let url = &base_uri/types/types?filter=contains(extensions,%str(%')&ext%str(%'));

  proc http oauth_bearer=sas_services out=&viyatypedef
    url="&url";
  run;

  %if &mdebug=1 %then %put DEBUG: &SYSMACRONAME &=url
    &=SYS_PROCHTTP_STATUS_CODE &=SYS_PROCHTTP_STATUS_PHRASE;

  %if (&SYS_PROCHTTP_STATUS_CODE ne 200) %then %do;
    /* To avoid a breaking change, exit early if the request failed.
      The calling process will proceed with empty requested macro variables. */
    %put INFO: &sysmacroname A response was not returned.;
    filename &viyatypedef clear;
    %return;
  %end;

  %if &mdebug=1 %then %do;
    data _null_;
        infile &viyatypedef;
        input;
        put "DEBUG: &SYSMACRONAME" _infile_;
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
  libname &libref1 JSON fileref=&viyatypedef automap=create;
  proc copy in=&libref1 out=&jsonlib; run;

  /* Populate typeDefName, if requested */
  %if (not %mf_isBlank(&typeDefNameVar)) %then %do;
    %let &typeDefNameVar = %mf_getvalue(&jsonlib..alldata,value,filter=%quote(p1="items" and p2="name"));
    %if &mdebug=1 %then %put DEBUG: &SYSMACRONAME &=typeDefNameVar &typeDefNameVar=&&&typeDefNameVar;
  %end;

  /* Populate mediaType, if requested */
  %if (not %mf_isBlank(&mediaTypeVar)) %then %do;
    %let &mediaTypeVar = %mf_getvalue(&jsonlib..alldata,value,filter=%quote(p1="items" and p2="mediaType"));
    %if &mdebug=1 %then %put DEBUG: &SYSMACRONAME &=mediaTypeVar &mediaTypeVar=&&&mediaTypeVar;
  %end;

  /* Populate properties macro variable, if requested */
  %if not %mf_isBlank(&propertiesVar) %then %do;
    /* Check for the items_properties table */
    %if ( not %mf_existds(&jsonlib..ITEMS_PROPERTIES) ) %then %do;
      %let &propertiesVar = %str();
      %if &mdebug=1 %then %put DEBUG: &SYSMACRONAME - No Viya properties found for file suffix %str(%')&ext%str(%');
    %end;
    %else %do;
      /* Properties potentially span multiple rows in the ITEMS_PROPERTIES table */
      /* First remove some unwanted variables from the items_properties dataset. */
      %let dsTemplate=%mf_getuniquename(prefix=dsTemplate_);
      data work.&dsTemplate;
        stop;
        set &jsonlib..ITEMS_PROPERTIES(drop=ordinal:);
      run;

      /* Retrieve the names of the remaining variables */
      /* These are the names of the properties. */
      %let varlist = %mf_getvarlist(work.&dsTemplate);
      %if &mdebug %then %put DEBUG: &SYSMACRONAME &=varlist;

      %let &propertiesVar = %quote({);

      %let nvars = %sysfunc(countw(&varlist));
      %do i = 1 %to &nvars;
        /* Use the name of each variable in the dataset as the property 'key' */
        %let key = %scan(&varlist,&i);
        %let value = %mf_getvalue(&jsonlib..ITEMS_PROPERTIES,&key);
        /* The data type determines if value should be quoted in the output*/
        %if %mf_getvartype(&jsonlib..ITEMS_PROPERTIES,&key) = C %then %do;
          %let value = "&value";
        %end;
        /* Transform the character '_', to '.' if found in the key */
        %let key = %sysfunc(translate(&key,.,_));
        /* Build the line to output */
        %let line="&key": &value;
        /* ...adding a comma to all but the final line in the object */
        %if &i < &nvars %then %let line = &line%str(,);
        %if &mdebug=1 %then %put DEBUG: &SYSMACRONAME line=%quote(&line);
        %let &propertiesVar = &&&propertiesVar %quote(&line);
      %end;
      /* Close off the properties object */
      %let &propertiesVar = &&&propertiesVar %quote(});
      %if &mdebug=1 %then %put DEBUG: &SYSMACRONAME &=propertiesVar &propertiesVar=&&&propertiesVar;
    %end;

  %end;

  %if &mdebug=0 %then %do;
    proc datasets library=&jsonlib nolist kill; quit;
    libname &jsonlib clear;
  %end;

  libname &libref1 clear;
  filename &viyatypedef clear;

%mend;