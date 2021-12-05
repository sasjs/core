/**
  @file
  @brief Guess the primary key of a table
  @details Tries to guess the primary key of a table based on the following
  logic:

      * Columns with nulls are ignored
      * Return only column combinations that provide unique results
      * Start from one column, then move out to composite keys of 2 to 6 columns

  The library of the target should be assigned before using this macro.

  Usage:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;
      %mp_guesspk(sashelp.class,outds=classpks)

  @param baseds The dataset to analyse
  @param outds= The output dataset to contain the possible PKs
  @param max_guesses= (3) The total number of possible primary keys to generate.
    A table may have multiple unlikely PKs, so no need to list them all.
  @param min_rows= (5) The minimum number of rows a table should have in order
    to try and guess the PK.

  <h4> SAS Macros </h4>
  @li mf_getvarlist.sas
  @li mf_getuniquename.sas
  @li mf_nobs.sas

  <h4> Related Macros </h4>
  @li mp_getpk.sas

  @version 9.3
  @author Allan Bowe

**/

%macro mp_guesspk(baseds
      ,outds=mp_guesspk
      ,max_guesses=3
      ,min_rows=5
)/*/STORE SOURCE*/;

  /* declare local vars */
  %local var vars vcnt i j k l tmpvar tmpds rows posspks ppkcnt;
  %let vars=%mf_getvarlist(&baseds);
  %let vcnt=%sysfunc(countw(&vars));

  %if &vcnt=0 %then %do;
    %put &sysmacroname: &baseds has no variables!  Exiting.;
    %return;
  %end;

  /* get null count and row count */
  %let tmpvar=%mf_getuniquename();
  proc sql noprint;
  create table _data_ as select
    count(*) as &tmpvar
  %do i=1 %to &vcnt;
    %let var=%scan(&vars,&i);
    ,sum(case when &var is missing then 1 else 0 end) as &var
  %end;
    from &baseds;

  /* transpose table and scan for not null cols */
  proc transpose;
  data _null_;
    set &syslast end=last;
    length vars $32767;
    retain vars ;
    if _name_="&tmpvar" then call symputx('rows',col1,'l');
    else if col1=0 then vars=catx(' ',vars,_name_);
    if last then call symputx('posspks',vars,'l');
  run;

  %let ppkcnt=%sysfunc(countw(&posspks));
  %if &ppkcnt=0 %then %do;
    %put &sysmacroname: &baseds has no non-missing variables!  Exiting.;
    %return;
  %end;

  proc sort data=&baseds(keep=&posspks) out=_data_ noduprec;
    by _all_;
  run;
  %local pkds; %let pkds=&syslast;

  %if &rows > %mf_nobs(&pkds) %then %do;
    %put &sysmacroname: &baseds has no combination of unique records! Exiting.;
    %return;
  %end;

  /* now check cardinality */
  proc sql noprint;
  create table _data_ as select
  %do i=1 %to &ppkcnt;
    %let var=%scan(&posspks,&i);
    count(distinct &var) as &var
    %if &i<&ppkcnt %then ,;
  %end;
    from &pkds;

  /* transpose and sort by cardinality */
  proc transpose;
  proc sort; by descending col1;
  run;

  /* create initial PK list and re-order posspks list */
  data &outds(keep=pkguesses);
    length pkguesses $5000 vars $5000;
    set &syslast end=last;
    retain vars ;
    vars=catx(' ',vars,_name_);
    if col1=&rows then do;
      pkguesses=_name_;
      output;
    end;
    if last then call symputx('posspks',vars,'l');
  run;

  %if %mf_nobs(&outds) ge &max_guesses %then %do;
    %put &sysmacroname: %mf_nobs(&outds) possible primary key values found;
    %return;
  %end;

  %if &ppkcnt=1 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* begin scanning for uniques on pairs of PKs */
  %let tmpds=%mf_getuniquename();
  %local lev1 lev2;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do;
        /* check for two level uniqueness */
        proc sort data=&pkds(keep=&lev1 &lev2) out=&tmpds noduprec;
          by _all_;
        run;
        %if %mf_nobs(&tmpds)=&rows %then %do;
          proc sql;
          insert into &outds values("&lev1 &lev2");
          %if %mf_nobs(&outds) ge &max_guesses %then %do;
            %put &sysmacroname: Max PKs reached at Level 2 for &baseds;
            %return;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=2 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* begin scanning for uniques on PK triplets */
  %local lev3;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do;
          /* check for three level uniqueness */
          proc sort data=&pkds(keep=&lev1 &lev2 &lev3) out=&tmpds noduprec;
            by _all_;
          run;
          %if %mf_nobs(&tmpds)=&rows %then %do;
            proc sql;
            insert into &outds values("&lev1 &lev2 &lev3");
            %if %mf_nobs(&outds) ge &max_guesses %then %do;
              %put &sysmacroname: Max PKs reached at Level 3 for &baseds;
              %return;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=3 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* scan for uniques on up to 4 PK fields */
  %local lev4;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do l=4 %to &ppkcnt;
          %let lev4=%scan(&posspks,&l);
          %if &lev1 ne &lev4 and &lev2 ne &lev4 and &lev3 ne &lev4 %then %do;
            /* check for four level uniqueness */
            proc sort data=&pkds(keep=&lev1 &lev2 &lev3 &lev4)
                out=&tmpds noduprec;
              by _all_;
            run;
            %if %mf_nobs(&tmpds)=&rows %then %do;
              proc sql;
              insert into &outds values("&lev1 &lev2 &lev3 &lev4");
              %if %mf_nobs(&outds) ge &max_guesses %then %do;
                %put &sysmacroname: Max PKs reached at Level 4 for &baseds;
                %return;
              %end;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=4 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* scan for uniques on up to 4 PK fields */
  %local lev5 m;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do l=4 %to &ppkcnt;
          %let lev4=%scan(&posspks,&l);
          %if &lev1 ne &lev4 and &lev2 ne &lev4 and &lev3 ne &lev4 %then
          %do m=5 %to &ppkcnt;
            %let lev5=%scan(&posspks,&m);
            %if &lev1 ne &lev5 & &lev2 ne &lev5 & &lev3 ne &lev5 & &lev4 ne &lev5 %then %do;
              /* check for four level uniqueness */
              proc sort data=&pkds(keep=&lev1 &lev2 &lev3 &lev4 &lev5)
                  out=&tmpds noduprec;
                by _all_;
              run;
              %if %mf_nobs(&tmpds)=&rows %then %do;
                proc sql;
                insert into &outds values("&lev1 &lev2 &lev3 &lev4 &lev5");
                %if %mf_nobs(&outds) ge &max_guesses %then %do;
                  %put &sysmacroname: Max PKs reached at Level 5 for &baseds;
                  %return;
                %end;
              %end;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=5 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

  /* scan for uniques on up to 4 PK fields */
  %local lev6 n;
  %do i=1 %to &ppkcnt;
    %let lev1=%scan(&posspks,&i);
    %do j=2 %to &ppkcnt;
      %let lev2=%scan(&posspks,&j);
      %if &lev1 ne &lev2 %then %do k=3 %to &ppkcnt;
        %let lev3=%scan(&posspks,&k);
        %if &lev1 ne &lev3 and &lev2 ne &lev3 %then %do l=4 %to &ppkcnt;
          %let lev4=%scan(&posspks,&l);
          %if &lev1 ne &lev4 and &lev2 ne &lev4 and &lev3 ne &lev4 %then
          %do m=5 %to &ppkcnt;
            %let lev5=%scan(&posspks,&m);
            %if &lev1 ne &lev5 & &lev2 ne &lev5 & &lev3 ne &lev5 & &lev4 ne &lev5 %then
            %do n=6 %to &ppkcnt;
              %let lev6=%scan(&posspks,&n);
              %if &lev1 ne &lev6 & &lev2 ne &lev6 & &lev3 ne &lev6
              & &lev4 ne &lev6 & &lev5 ne &lev6 %then
              %do;
                /* check for four level uniqueness */
                proc sort data=&pkds(keep=&lev1 &lev2 &lev3 &lev4 &lev5 &lev6)
                  out=&tmpds noduprec;
                  by _all_;
                run;
                %if %mf_nobs(&tmpds)=&rows %then %do;
                  proc sql;
                  insert into &outds
                    values("&lev1 &lev2 &lev3 &lev4 &lev5 &lev6");
                  %if %mf_nobs(&outds) ge &max_guesses %then %do;
                    %put &sysmacroname: Max PKs reached at Level 6 for &baseds;
                    %return;
                  %end;
                %end;
              %end;
            %end;
          %end;
        %end;
      %end;
    %end;
  %end;

  %if &ppkcnt=6 %then %do;
    %put &sysmacroname: No more PK guess possible;
    %return;
  %end;

%mend mp_guesspk;