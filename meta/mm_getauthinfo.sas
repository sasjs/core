/**
  @file mm_getauthinfo.sas
  @brief Extracts authentication info for each user in metadata
  @details
  Usage:

      %mm_getauthinfo(outds=auths)


  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages and preserve outputs
  @param [out] outds= (mm_getauthinfo) The output dataset to create

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquename.sas
  @li mm_getdetails.sas
  @li mm_getobjects.sas


  @version 9.4
  @author Allan Bowe

**/

%macro mm_getauthinfo(outds=mm_getauthinfo
  ,mdebug=0
)/*/STORE SOURCE*/;
%local prefix fileref;
%let prefix=%substr(%mf_getuniquename(),1,25);

%mm_getobjects(type=Login,outds=&prefix.0)

%local fileref;
%let fileref=%mf_getuniquefileref();

data _null_;
  file &fileref;
  set &prefix.0 end=last;
  /* run macro */
  str=cats('%mm_getdetails(uri=',id,",outattrs=&prefix.d",_n_
    ,",outassocs=&prefix.a",_n_,")");
  put str;
  /* transpose attributes */
  str=cats("proc transpose data=&prefix.d",_n_,"(drop=type) out=&prefix.da"
    ,_n_,"(drop=_name_);var value;id name;run;");
  put str;
  /* add extra info to attributes */
  str=cats("data &prefix.da",_n_,";length login_id login_name $256; login_id="
    ,quote(trim(id)),";set &prefix.da",_n_
    ,";login_name=trim(subpad(name,1,256));drop name;run;");
  put str;
  /* add extra info to associations */
  str=cats("data &prefix.a",_n_,";length login_id login_name $256; login_id="
    ,quote(trim(id)),";login_name=",quote(trim(name))
    ,";set &prefix.a",_n_,";run;");
  put str;
  if last then do;
    /* collate attributes */
    str=cats("data &prefix._logat; set &prefix.da1-&prefix.da",_n_,";run;");
    put str;
    /* collate associations */
    str=cats("data &prefix._logas; set &prefix.a1-&prefix.a",_n_,";run;");
    put str;
    /* tidy up */
    str=cats("proc delete data=&prefix.da1-&prefix.da",_n_,";run;");
    put str;
    str=cats("proc delete data=&prefix.d1-&prefix.d",_n_,";run;");
    put str;
    str=cats("proc delete data=&prefix.a1-&prefix.a",_n_,";run;");
    put str;
  end;
run;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fileref;
    if _n_=1 then putlog // "Now executing the following code:" //;
    input; putlog _infile_;
  run;
%end;
%inc &fileref;
filename &fileref clear;

/* get libraries */
proc sort data=&prefix._logas(where=(assoc='Libraries')) out=&prefix._temp;
  by login_id;
data &prefix._temp;
  set &prefix._temp;
  by login_id;
  length library_list $32767;
  retain library_list;
  if first.login_id then library_list=name;
  else library_list=catx(' !! ',library_list,name);
proc sql;
/* get auth domain */
create table &prefix._dom as
  select login_id,name as domain
  from &prefix._logas
  where assoc='Domain';
create unique index login_id on &prefix._dom(login_id);
/* join it all together */
create table &outds as
  select a.*
    ,c.domain
    ,b.library_list
  from &prefix._logat (drop=ishidden lockedby usageversion publictype) a
  left join &prefix._temp b
  on a.login_id=b.login_id
  left join &prefix._dom c
  on a.login_id=c.login_id;

%if &mdebug=0 %then %do;
  proc datasets lib=work;
    delete &prefix:;
  run;
%end;


%mend mm_getauthinfo;