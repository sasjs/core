/**
  @file
  @brief Used to capture scope leakage of macro variables
  @details

  A common 'difficult to detect' bug in macros is where a nested macro
  over-writes variables in a higher level macro.

  This assertion takes a snapshot of the macro variables before and after
  a macro invocation.  Differences are captured in the `&outds` table. This
  makes it easy to detect whether any macro variables were modified or
  changed.

  If you would like this feature, feel free to contribute / raise an issue /
  engage the SASjs team directly.

  Example usage:

      %mp_assertscope(SNAPSHOT)

      %let oops=I did it again;

      %mp_assertscope(COMPARE,
        desc=Checking macro variables against previous snapshot
      )

  This macro is designed to work alongside `sasjs test` - for more information
  about this facility, visit [cli.sasjs.io/test](https://cli.sasjs.io/test).

  @param [in] action (SNAPSHOT) The action to take.  Valid values:
    @li SNAPSHOT - take a copy of the current macro variables
    @li COMPARE - compare the current macro variables against previous values
  @param [in] scope= (GLOBAL) The scope of the variables to be checked.  This
    corresponds to the values in the SCOPE column in `sashelp.vmacro`.
  @param [in] desc= (Testing scope leakage) The user provided test description
  @param [in,out] scopeds= (work.mp_assertscope) The dataset to contain the
    scope snapshot
  @param [out] outds= (work.test_results) The output dataset to contain the
  results.  If it does not exist, it will be created, with the following format:
  |TEST_DESCRIPTION:$256|TEST_RESULT:$4|TEST_COMMENTS:$256|
  |---|---|---|
  |User Provided description|PASS|No out of scope variables created or modified|

  <h4> Related Macros </h4>
  @li mp_assert.sas
  @li mp_assertcols.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.test.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_assertscope(action,
  desc=Testing Scope Leakage,
  scope=GLOBAL,
  scopeds=work.mp_assertscope,
  outds=work.test_results
)/*/STORE SOURCE*/;
%local ds test_result test_comments del add mod;

/* get current variables */
%if &action=SNAPSHOT %then %do;
  proc sql;
  create table &scopeds as
    select name,offset,value
    from dictionary.macros
    where scope="&scope"
    order by name,offset;
%end;
%else %if &action=COMPARE %then %do;

  proc sql;
  create table _data_ as
    select name,offset,value
    from dictionary.macros
    where scope="&scope"
    order by name,offset;

  %let ds=&syslast;

  proc compare base=&scopeds compare=&ds;
  run;

  %if &sysinfo=0 %then %do;
    %let test_result=PASS;
    %let test_comments=&scope Variables Unmodified;
  %end;
  %else %do;
    proc sql noprint undo_policy=none;
    select distinct name into: del separated by ' '  from &scopeds
      where name not in (select name from &ds);
    select distinct name into: add separated by ' '  from &ds
      where name not in (select name from &scopeds);
    select distinct a.name into: mod separated by ' '
      from &scopeds a
      inner join &ds b
      on a.name=b.name
        and a.offset=b.offset
      where a.value ne b.value;
    %let test_result=FAIL;
    %let test_comments=%str(Mod:(&mod) Add:(&add) Del:(&del));
  %end;


  data ;
    length test_description $256 test_result $4 test_comments $256;
    test_description=symget('desc');
    test_comments=symget('test_comments');
    test_result=symget('test_result');
  run;

  %let ds=&syslast;
  proc append base=&outds data=&ds;
  run;
  proc sql;
  drop table &ds;
%end;

%mend mp_assertscope;