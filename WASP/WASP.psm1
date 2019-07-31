$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in @($Public + $Private))
{
  try
  {
    . $import.fullname
  
  }
  catch
  {
    Write-Error -Message "Failed to import function $($import.fullname): $_"
  }
  
  
}

$wasp = @'
 
" ,  ,
   ", ,
      ""     _---.    ..;%%%;, .
        "" .",  ,  .==% %%%%%%% ' .
          "", %%%   =%% %%%%%%;  ; ;-_
          %; %%%%%  .;%;%%%"%p ---; _  '-_
          %; %%%%% __;%%;p/; O        --_ "-,_
           q; %%% /v \;%p ;%%%%%;--__    "'-__'-._
           //\\" // \  % ;%%%%%%%;',/%\_  __  "'-_'\_
           \  / //   \/   ;%% %; %;/\%%%%;;;;\    "- _\
              ,"             %;  %%;  %%;;'  ';%       -\-_
         -=\="             __%    %%;_ |;;    %%%\          \
                         _/ _=      \==_;;,_ %%%; % -_      /
                        / /-          =%- ;%%%%; %%;  "--__/
                       //=             ==%-%%;  %; %
                       /             _=_-  d  ;%; ;%;  :F_P:
                       \            =,-"    d%%; ;%%;
                                   //        %  ;%%;
                                  //          d%%%"
                                   \           %%
                                               V                                               

                  \ \ /\ / / _` / __| '_ \ 
                   \ V  V / (_| \__ \ |_) |
                    \_/\_/ \__,_|___/ .__/ 
                                    | |    
                                    |_|  
'@


Export-ModuleMember -Function $Public.Basename
Write-host $wasp