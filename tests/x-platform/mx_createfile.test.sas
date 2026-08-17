/**
  @file
  @brief Testing mx_createfile macro

  Be sure to run <code>%let mcTestAppLoc=/Public/temp/macrocore;</code> when
  running in Studio

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas
  @li mf_uid.sas
  @li mfv_existfile.sas
  @li mm_getstpcode.sas
  @li mp_assert.sas
  @li mp_assertscope.sas
  @li ms_getfile.sas
  @li mx_createfile.sas

**/

/* create the content to write */
filename ft15f001 temp;
data _null_;
  file ft15f001;
  put '%let test1=SUCCESS;';
run;

%let item=%mf_uid();

/* create the file, checking for scope leakage */
%mp_assertscope(SNAPSHOT)
%mx_createfile(&mcTestAppLoc/temp/&item, inref=ft15f001)
%mp_assertscope(COMPARE,
  desc=Test 1: mx_createfile does not leak scope,
  ignorelist=MC0_JADP1LEN MC0_JADP2LEN MC0_JADP3LEN MC0_JADPNUM
    MC0_JADVLEN MC2_JADP1LEN MC2_JADP2LEN MC2_JADPNUM MC2_JADVLEN
    VIYAPROPERTIES VIYATYPEDEFNAME,
  outds=work.test_results
)

/* verify per platform (open code must be wrapped in a macro) */
%global test1;
%let test1=FAIL;

%macro check_content();
  %let platform=%mf_getplatform();
  %if &platform=SASJS %then %do;
    /* read the file back from the drive and check the content executes */
    %ms_getfile(&mcTestAppLoc/temp/&item..sas, outref=testref1)
    %inc testref1;
  %end;
  %else %if &platform=SAS9 or &platform=SASMETA %then %do;
    /* a type 2 STP now exists in metadata with the code embedded */
    %mm_getstpcode(tree=&mcTestAppLoc/temp/&item, outref=testref2)
    %inc testref2;
  %end;
  %else %if &platform=SASVIYA %then %do;
    /* read the file back from SAS Content and check the content executes */
    filename testref3 filesrvc folderpath="&mcTestAppLoc/temp";
    %inc testref3(&item)/source2;
  %end;
%mend check_content;
%check_content()

%macro assert_result();
  %let platform=%mf_getplatform();
  %if &platform=SASVIYA %then %do;
    %mp_assert(
      iftrue=(%mfv_existfile(&mcTestAppLoc/temp/&item)=1),
      desc=Test 1: VIYA - content file created,
      outds=work.test_results
    )
    %mp_assert(
      iftrue=(&test1=SUCCESS),
      desc=Test 2: VIYA - file created with correct content,
      outds=work.test_results
    )
  %end;
  %else %do;
    %mp_assert(
      iftrue=(&test1=SUCCESS),
      desc=Test 1: file created with correct content (&platform),
      outds=work.test_results
    )
  %end;
%mend assert_result;
%assert_result()
