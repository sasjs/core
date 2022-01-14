/**
  @file
  @brief Prepares an audit table for stacking (re-applying) the changes.
  @details WORK IN PROGRESS!!

    When the underlying data from a Base Table is refreshed, it can be helpful
    to have any previously-applied changes, re-applied.

    Such situation might arise if you are applying those changes using a tool
    like [Data Controller for SAS®](https://datacontroller.io) - which records
    all such changes in an audit table.
    It may also apply if you are preparing a series of specific cell-level
    transactions, that you would like to apply to multiple sets of (similarly
    structured) Base Tables.

    In both cases, it is necessary that the transactions are stored using
    the mp_storediffs.sas macro, or at least that the underlying table is
    structured as per the definition in mp_coretable.sas (DIFFTABLE entry)

    <b>This</b> macro is used to convert the stored changes (tall format) into
    staged changes (wide format), with base table values incorporated (in the
    case of modified rows), ready for the subsequent load process.

    Essentially then, what this macro does, is turn a table like this:

  |LIBREF:$8.|DSN:$32.|MOVE_TYPE:$1.|TGTVAR_NM:$32.|IS_PK:best.|IS_DIFF:best.|TGTVAR_TYPE:$1.|OLDVAL_NUM:best32.|NEWVAL_NUM:best32.|OLDVAL_CHAR:$32765.|NEWVAL_CHAR:$32765.|
  |---|---|---|---|---|---|---|---|---|---|---|
  |`SASHELP `|`CLASS `|`A `|`NAME `|`1 `|`-1 `|`C `|`. `|`. `|` `|`Newbie `|
  |`SASHELP `|`CLASS `|`A `|`AGE `|`0 `|`-1 `|`N `|`. `|`13 `|` `|` `|
  |`SASHELP `|`CLASS `|`A `|`HEIGHT `|`0 `|`-1 `|`N `|`. `|`65.3 `|` `|` `|
  |`SASHELP `|`CLASS `|`A `|`SEX `|`0 `|`-1 `|`C `|`. `|`. `|` `|`F `|
  |`SASHELP `|`CLASS `|`A `|`WEIGHT `|`0 `|`-1 `|`N `|`. `|`98 `|` `|` `|
  |`SASHELP `|`CLASS `|`D `|`NAME `|`1 `|`-1 `|`C `|`. `|`. `|`Alfred `|` `|
  |`SASHELP `|`CLASS `|`D `|`AGE `|`0 `|`-1 `|`N `|`14 `|`. `|` `|` `|
  |`SASHELP `|`CLASS `|`D `|`HEIGHT `|`0 `|`-1 `|`N `|`69 `|`. `|` `|` `|
  |`SASHELP `|`CLASS `|`D `|`SEX `|`0 `|`-1 `|`C `|`. `|`. `|`M `|` `|
  |`SASHELP `|`CLASS `|`D `|`WEIGHT `|`0 `|`-1 `|`N `|`112.5 `|`. `|` `|` `|
  |`SASHELP `|`CLASS `|`M `|`NAME `|`1 `|`0 `|`C `|`. `|`. `|`Alice `|`Alice `|
  |`SASHELP `|`CLASS `|`M `|`AGE `|`0 `|`1 `|`N `|`13 `|`99 `|` `|` `|
  |`SASHELP `|`CLASS `|`M `|`HEIGHT `|`0 `|`0 `|`N `|`56.5 `|`56.5 `|` `|` `|
  |`SASHELP `|`CLASS `|`M `|`SEX `|`0 `|`0 `|`C `|`. `|`. `|`F `|`F `|
  |`SASHELP `|`CLASS `|`M `|`WEIGHT `|`0 `|`0 `|`N `|`84 `|`84 `|` `|` `|

    Into three tables like this:

  <b> `work.outmod`: </b>
  |NAME:$8.|SEX:$1.|AGE:best.|HEIGHT:best.|WEIGHT:best.|
  |---|---|---|---|---|
  |`Alice `|`F `|`99 `|`56.5 `|`84 `|

  <b> `work.outadd`: </b>
  |NAME:$8.|SEX:$1.|AGE:best.|HEIGHT:best.|WEIGHT:best.|
  |---|---|---|---|---|
  |`Newbie `|`F `|`13 `|`65.3 `|`98 `|

  <b> `work.outdel`: </b>
  |NAME:$8.|SEX:$1.|AGE:best.|HEIGHT:best.|WEIGHT:best.|
  |---|---|---|---|---|
  |`Alfred `|`M `|`14 `|`69 `|`112.5 `|

    As you might expect, there are a bunch of extra features and checks.

    The macro supports both SCD2 (TXTEMPORAL) and UPDATE loadtypes. If the
    base table contains a PROCESSED_DTTM column (or similar), this can be
    ignored by declaring it in the `processed_dttm_var` parameter.

    If the structure of the Base Table has changed, the following rules apply:

    @li New Columns - Irrelevant for deletes.  For inserts, the new column
      values are set to missing. For updates, the base table values are used.
    @li Deleted Columns - These will also be absent in the output tables.
    @li Change in Primary Key - This is not (well, cannot be) supported!!

    Rules for stacking changes are as follows:

    <table>
    <tr><th>Transaction Type</th><th>Behaviour</th></tr>
    <tr>
      <td>Deletes</td>
      <td>
        For previously deleted rows, the PK is added to the `outDEL` table<br>
        If the row no longer exists in the base table, the row is added to the
        `errDS` table instead.
      </td>
    </tr>
    <tr>
      <td>Inserts</td>
      <td>
        Previously newly added rows are added to the `outADD` table UNLESS they
        are present in the Base table.<br>In this case they are added to the
        `errDS` table instead.
      </td>
    </tr>
    <tr>
      <td>Updates</td>
      <td>
        Previously modified rows are merged with base table values such that
        only the individual cells that were _previously_ changed are re-applied.
        Where the row contains cells that were not marked as having changed in
        the prior transaction, the 'blanks' are filled with base table values in
        the `outMOD` table.<br>
        If the row no longer exists on the base table, then the row is added to
        the `errDS` table instead.
      </td>
    </tr>
    </table>

    To illustrate the above with a diagram:

    @dot
      digraph {
        rankdir="TB"

        start[label="Transaction Type?" shape=Mdiamond]
        del[label="Base Row Exists?" shape=rectangle]
        add [label="Base Row Exists?" shape=rectangle]
        mod [label="Base Row Exists?" shape=rectangle]
        outmod [label="outMOD Table" shape=box3d]
        outadd [label="outADD Table" shape=box3d]
        outdel [label="outDEL Table" shape=box3d]
        outerr [label="ErrDS Table" shape=box3d]
        start -> del [label="Delete"]
        start -> add [label="Insert"]
        start -> mod [label="Update"]

        del -> outdel [label="Yes"]
        del -> outerr [label="No" color="Red" fontcolor="Red"]
        add -> outadd [label="Yes"]
        add -> outerr [label="No" color="Red" fontcolor="Red"]
        mod -> outerr [label="Yes" color="Red" fontcolor="Red"]
        mod -> outmod [label="No"]

      }
    @enddot

    For examples of usage, check out the mp_stackdiffs.test.sas program.


  @param [in] baselibds Base Table against which the changes will be applied,
    in libref.dataset format.
  @param [in] auditlibds Dataset with previously applied transactions, to be
    re-applied. Use libref.dataset format.
    DDL as follows:  %mp_coretable(DIFFTABLE)
  @param [in] key Space seperated list of key variables
  @param [in] mdebug= Set to 1 to enable DEBUG messages and preserve outputs
  @param [in] processed_dttm_var= (0) If a variable is being used to mark
    the processed datetime, put the name of the variable here.  It will NOT
    be included in the staged dataset (the load process is expected to
    provide this)
  @param [out] errds= (work.errds) Output table containing problematic records.
    The columns of this table are:
    @li PK_VARS - Space separated list of primary key variable names
    @li PK_VALS - Slash separted list of PK variable values
    @li ERR_MSG - Explanation of why this record is problematic
  @param [out] outmod= (work.outmod) Output table containing modified records
  @param [out] outadd= (work.outadd) Output table containing additional records
  @param [out] outdel= (work.outdel) Output table containing deleted records


  <h4> SAS Macros </h4>
  @li mf_getuniquename.sas
  @li mf_islibds.sas
  @li mp_abort.sas


  <h4> Related Macros </h4>
  @li mp_coretable.sas
  @li mp_storediffs.sas

  @version 9.2
  @author Allan Bowe
**/
/** @cond */

%macro mp_stackdiffs(baselibds
  ,auditlibds
  ,key
  ,mdebug=0
  ,processed_dttm_var=0
  ,errds=work.errds
  ,outmod=work.outmod
  ,outadd=work.outadd
  ,outdel=work.outdel
)/*/STORE SOURCE*/;
%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

/* input parameter validations */
%mp_abort(iftrue= (%mf_islibds(&baselibds) ne 1)
  ,mac=&sysmacroname
  ,msg=%str(Invalid baselibds: &baselibds)
)
%mp_abort(iftrue= (%mf_islibds(&auditlibds) ne 1)
  ,mac=&sysmacroname
  ,msg=%str(Invalid auditlibds: &auditlibds)
)
%mp_abort(iftrue= (%length(&key)=0)
  ,mac=&sysmacroname
  ,msg=%str(Missing key variables!)
)

/* set up unique and temporary vars */
%local ds1 ds2 ds3 ds4 hashkey inds_auto inds_keep dslist;
%let ds1=%upcase(work.%mf_getuniquename(prefix=mpsd_ds1));
%let ds2=%upcase(work.%mf_getuniquename(prefix=mpsd_ds2));
%let ds3=%upcase(work.%mf_getuniquename(prefix=mpsd_ds3));
%let ds4=%upcase(work.%mf_getuniquename(prefix=mpsd_ds4));
%let hashkey=%upcase(%mf_getuniquename(prefix=mpsd_hashkey));
%let inds_auto=%upcase(%mf_getuniquename(prefix=mpsd_inds_auto));
%let inds_keep=%upcase(%mf_getuniquename(prefix=mpsd_inds_keep));

%let key=%upcase(&key);

%if &mdebug=0 %then %do;
  proc sql;
  drop table &ds1, &ds2, &ds3, &ds4;
%end;

%mend mp_stackdiffs;
/** @endcond */