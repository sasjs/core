 /**
   @file mv_getaccesstoken.sas
   @brief deprecated - replaced by mv_tokenrefresh.sas

   @version VIYA V.03.04
   @author Allan Bowe
   @source https://github.com/macropeople/macrocore
 
   <h4> Dependencies </h4>
   @li mv_tokenrefresh.sas

 **/
 
 %macro mv_getaccesstoken(client_id=someclient
     ,client_secret=somesecret
     ,grant_type=authorization_code
     ,code=
     ,user=
     ,pass=
     ,access_token_var=ACCESS_TOKEN
     ,refresh_token_var=REFRESH_TOKEN
   );

%mv_tokenrefresh(client_id=&client_id
  ,client_secret=&client_secret
  ,grant_type=&grant_type
  ,user=&user
  ,pass=&pass
  ,access_token_var=&access_token_var
  ,refresh_token_var=&refresh_token_var
)

%mend;