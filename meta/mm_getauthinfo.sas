/**
  @file mm_getauthinfo.sas
  @brief extracts authentication info
  @details usage:

    %mm_getauthinfo(outds=auths)

  @param outds= the ONE LEVEL work dataset to create

  <h4> SAS Macros </h4>
  @li mm_getobjects.sas
  @li mf_getuniquefileref.sas
  @li mm_getdetails.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mm_getauthinfo(outds=mm_getauthinfo
)/*/STORE SOURCE*/;

%if %length(&outds)>30 %then %do;
  %put %str(ERR)OR: Temp tables are created with the &outds prefix, which
    therefore needs to be 30 characters or less;
  %return;
%end;
%if %index(&outds,'.')>0 %then %do;
  %put %str(ERR)OR: Table &outds should be ONE LEVEL (no library);
  %return;
%end;

%mm_getobjects(type=Login,outds=&outds.0)

%local fileref;
%let fileref=%mf_getuniquefileref();

data _null_;
  file &fileref;
  set &outds.0 end=last;
  /* run macro */
  str=cats('%mm_getdetails(uri=',id,",outattrs=&outds.d",_n_
    ,",outassocs=&outds.a",_n_,")");
  put str;
  /* transpose attributes */
  str=cats("proc transpose data=&outds.d",_n_,"(drop=type) out=&outds.da"
    ,_n_,"(drop=_name_);var value;id name;run;");
  put str;
  /* add extra info to attributes */
  str=cats("data &outds.da",_n_,";length login_id login_name $256; login_id="
    ,quote(trim(id)),";set &outds.da",_n_
    ,";login_name=trim(subpad(name,1,256));drop name;run;");
  put str;
  /* add extra info to associations */
  str=cats("data &outds.a",_n_,";length login_id login_name $256; login_id="
    ,quote(trim(id)),";login_name=",quote(trim(name))
    ,";set &outds.a",_n_,";run;");
  put str;
  if last then do;
    /* collate attributes */
    str=cats("data &outds._logat; set &outds.da1-&outds.da",_n_,";run;");
    put str;
    /* collate associations */
    str=cats("data &outds._logas; set &outds.a1-&outds.a",_n_,";run;");
    put str;
    /* tidy up */
    str=cats("proc delete data=&outds.da1-&outds.da",_n_,";run;");
    put str;
    str=cats("proc delete data=&outds.d1-&outds.d",_n_,";run;");
    put str;
    str=cats("proc delete data=&outds.a1-&outds.a",_n_,";run;");
    put str;
  end;
run;
%inc &fileref;

/* get libraries */
proc sort data=&outds._logas(where=(assoc='Libraries')) out=&outds._temp;
  by login_id;
data &outds._temp;
  set &outds._temp;
  by login_id;
  length library_list $32767;
  retain library_list;
  if first.login_id then library_list=name;
  else library_list=catx(' !! ',library_list,name);
proc sql;
/* get auth domain */
create table &outds._dom as
  select login_id,name as domain
  from &outds._logas
  where assoc='Domain';
create unique index login_id on &outds._dom(login_id);
/* join it all together */
create table &outds._logins as
  select a.*
    ,c.domain
    ,b.library_list
  from &outds._logat (drop=ishidden lockedby usageversion publictype) a
  left join &outds._temp b
  on a.login_id=b.login_id
  left join &outds._dom c
  on a.login_id=c.login_id;
drop table &outds._temp;
drop table &outds._logat;
drop table &outds._logas;

data _null_;
  infile &fileref;
  if _n_=1 then putlog // "Now executing the following code:" //;
  input; putlog _infile_;
run;

filename &fileref clear;

%mend;