 /**
   @file mv_getrefreshtoken.sas
   @brief deprecated - replaced by mv_tokenauth.sas

   @version VIYA V.03.04
   @author Allan Bowe
   @source https://github.com/sasjs/core
 
   <h4> Dependencies </h4>
   @li mv_tokenauth.sas

 **/
 
 %macro mv_getrefreshtoken(client_id=someclient
     ,client_secret=somesecret
     ,grant_type=authorization_code
     ,code=
     ,user=
     ,pass=
     ,access_token_var=ACCESS_TOKEN
     ,refresh_token_var=REFRESH_TOKEN
   );

%mv_tokenauth(client_id=&client_id
  ,client_secret=&client_secret
  ,grant_type=&grant_type
  ,code=&code
  ,user=&user
  ,pass=&pass
  ,access_token_var=&access_token_var
  ,refresh_token_var=&refresh_token_var
)

%mend;