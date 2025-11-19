/**
  @file
  @brief Testing mv_getviyafileextparms macro

  <h4> SAS Macros </h4>
  @li mf_isblank.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li mv_getviyafileextparms.sas

**/

options mprint;

%let mvarIgnoreList =
  MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM MC0_JADVLEN
  SASJSPROCESSMODE SASJS_STPSRV_HEADER_LOC;

%put TEST 1 - Test with common extension, requesting only typeDefName parameter;
%mp_assertscope(SNAPSHOT)
%mv_getviyafileextparms(ext=txt, typeDefNameVar=viyaTypeDefName)
%mp_assertscope(COMPARE
  ,ignorelist=&mvarIgnoreList viyaTypeDefName
)

%mp_assert(
  iftrue=(not %mf_isBlank(&viyaTypeDefName)),
  desc=Check the requested macro variable viyaTypeDefName is not blank.
)

%put TEST 2 - Test with common extension, requesting only properties parameter;
%mp_assertscope(SNAPSHOT)
%mv_getviyafileextparms(ext=html, propertiesVar=viyaProperties)
%mp_assertscope(COMPARE
  ,ignorelist=&mvarIgnoreList viyaProperties
)

%mp_assert(
  iftrue=(not %mf_isBlank(%superq(viyaProperties))),
  desc=Check the requested macro variable viyaProperties is not blank.
)

%put TEST 3 - Test with common extension, requesting only mediaType parameter;
%mp_assertscope(SNAPSHOT)
%mv_getviyafileextparms(ext=mp3, mediaTypeVar=viyaMediaType)
%mp_assertscope(COMPARE
  ,ignorelist=&mvarIgnoreList viyaMediaType
)

%mp_assert(
  iftrue=(not %mf_isBlank(&viyaMediaType)),
  desc=Check the requested macro variable viyaMediaType is not blank.
)

%put TEST 4 - Test with common extension, requesting all parameters;
%mp_assertscope(SNAPSHOT)
%mv_getviyafileextparms(
  ext=css,
  typeDefNameVar=cssViyaTypeDefName,
  propertiesVar=cssViyaProperties,
  mediaTypeVar=cssViyaMediaType
  )
%mp_assertscope(COMPARE
  ,ignorelist=
    &mvarIgnoreList cssViyaTypeDefName cssViyaProperties  cssViyaMediaType
)

%mp_assert(
  iftrue=(not ( %mf_isBlank(&cssViyaTypeDefName) or
                %mf_isBlank(%superq(cssViyaProperties)) or
                %mf_isBlank(&cssViyaMediaType) ) ),
  desc=Check a full set of requested macro variables are not blank.
)


%put TEST 5 - Test with invalid extension - requested parameters will be blank;
%mp_assertscope(SNAPSHOT)
%mv_getviyafileextparms(
  ext=xxxINVALIDxxx,
  typeDefNameVar=invalidTypeDefName,
  propertiesVar=invalidProperties,
  mediaTypeVar=invalidMediaType
  )
%mp_assertscope(COMPARE
  ,ignorelist=
    &mvarIgnoreList invalidTypeDefName invalidProperties invalidMediaType
)

%mp_assert(
  iftrue=(
    %mf_isBlank(&invalidTypeDefName) and
    %mf_isBlank(%superq(invalidProperties)) and
    %mf_isBlank(&invalidMediaType)
    ),
  desc=Check the requested macro variables are all blank.
)
