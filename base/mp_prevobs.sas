/**
  @file
  @brief Enables previous observations to be re-instated
  @details Remembers the last X observations by storing them in a hash table.
  Is a convenience over the use of lag() or retain, when an entire observation
  needs to be restored.

  This macro will also restore automatic variables (such as _n_ and _error_).

  Example Usage:

      data example;
        set sashelp.class;
        calc_var=_n_*3;
        * initialise hash and save from PDV ;
        %mp_prevobs(INIT,history=2)
        if _n_ =10 then do;
          * fetch previous but 1 record;
          %mp_prevobs(FETCH,-2) 
          put _n_= name= age= calc_var=; 
          * fetch previous record;
          %mp_prevobs(FETCH,-1) 
          put _n_= name= age= calc_var=; 
          * reinstate current record ;
          %mp_prevobs(FETCH,0) 
          put _n_= name= age= calc_var=;
        end;
      run;

  Result:

  <img src="https://imgur.com/PSjHoET.png" alt="mp_prevobs sas" width="400"/>

  Credit is made to `data _null_` for authoring this very helpful paper:
  https://www.lexjansen.com/pharmasug/2008/cc/CC08.pdf

  @param action Either FETCH a current or previous record, or INITialise.
  @param record The relative (to current) position of the previous observation 
   to return.  
  @param history= The number of records to retain in the hash table. Default=5
  @param prefix= the prefix to give to the variables used to store the hash name
   and index. Default=mp_prevobs

  @version 9.2
  @author Allan Bowe

**/

%macro mp_prevobs(action,record,history=5,prefix=mp_prevobs
)/*/STORE SOURCE*/;
%let action=%upcase(&action);
%let prefix=%upcase(&prefix);
%let record=%eval((&record+0) * -1);

%if &action=INIT %then %do;
    
  if _n_ eq 1 then do; 
    attrib &prefix._VAR length=$64; 
    dcl hash &prefix._HASH(ordered:'Y');
    &prefix._KEY=0;
    &prefix._HASH.defineKey("&prefix._KEY"); 
    do while(1); 
      call vnext(&prefix._VAR); 
      if &prefix._VAR='' then leave;
      if &prefix._VAR eq "&prefix._VAR" then continue; 
      else if &prefix._VAR eq "&prefix._KEY" then continue; 
      &prefix._HASH.defineData(&prefix._VAR);
    end; 
    &prefix._HASH.defineDone(); 
  end;
  /* this part has to happen before FETCHing */
  &prefix._KEY+1;
  &prefix._rc=&prefix._HASH.add();
  if &prefix._rc then putlog 'adding' &prefix._rc=;
  %if &history>0 %then %do;
    if &prefix._key>&history+1 then 
      &prefix._HASH.remove(key: &prefix._KEY - &history - 1);
    if &prefix._rc then putlog 'removing' &prefix._rc=;
  %end;
%end;
%else %if &action=FETCH %then %do;
  if &record > &prefix._key then putlog "Not enough records in &Prefix._hash yet";
  else &prefix._rc=&prefix._HASH.find(key: &prefix._KEY - &record);
  if &prefix._rc then putlog &prefix._rc= " when fetching " &prefix._KEY=
    "with record &record and " _n_=;
%end;

%mend;