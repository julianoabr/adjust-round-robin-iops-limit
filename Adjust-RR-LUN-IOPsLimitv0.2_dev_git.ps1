#Requires -Version 5.1
#Requires -RunAsAdministrator   

<#
.Synopsis
   Change de IOPS LIMIT RR Value
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.BASE
   Based on KB:
   https://kb.vmware.com/s/article/2069356
   
   https://kb.vmware.com/s/article/1011340

   https://infohub.delltechnologies.com/l/day-one-best-practices/vmware-esxi-round-robin-path-policy

.AUTHOR
    Juliano Alves de Brito Ribeiro (find me at julianoalvesbr@live.com or https://github.com/julianoabr or https://youtube.com/@powershellchannel)
.VERSION
    0.2
#>
Clear-Host

#VALIDATE MODULE
$moduleExists = Get-Module -Name Vmware.VimAutomation.Core

if ($moduleExists){
    
    Write-Output "The Module Vmware.VimAutomation.Core is already loaded"
    
}#if validate module
else{
    
    Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
}#else validate module

Set-PowerCLIConfiguration -WebOperationTimeoutSeconds 900 -Verbose -Confirm:$false -ErrorAction Continue

$Script:pathOutput = "$env:SystemDrive\Tmp\Vmware\Host\AdjustRoundRobin"

$currentDate = (Get-Date -Format "ddMMyyyy").ToString()

#DEFINE VCENTER LIST
$vcServerList = @();

#ADD OR REMOVE VCs        
$vcServerList = ('vCenter-1','vCenter-2','vCenter-3','vCenter-4','vCenter-4','vCenter-5','vCenter-6') | Sort-Object


function Pause-PSScript
{

   Read-Host 'Pressione [ENTER] para continuar' | Out-Null

}

#VALIDATE IF OPTION IS NUMERIC
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
} #end function is Numeric


#FUNCTION CONNECT TO VCENTER
function Connect-ToVcenterServer
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('Manual','Automatic')]
        $methodToConnect = 'Manual',

        # Param2 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateSet('vCenter-1','vCenter-2','vCenter-3','vCenter-4','vCenter-4','vCenter-5','vCenter-6')]
        [System.String]$vCenterToConnect, 
        
        [Parameter(Mandatory=$false,
                   Position=2)]
        [System.String[]]$VCServers, 
                
        [Parameter(Mandatory=$false,
                   Position=3)]
        [ValidateSet('domain.suffix1','domain.suffix2','domain.suffix3','domain.suffix4')]
        [System.String]$suffix, 

        [Parameter(Mandatory=$false,
                   Position=4)]
        [ValidateSet('80','443')]
        [System.String]$port = '443'
    )

        

    if ($methodToConnect -eq 'Automatic'){
                
        $Script:workingServer = $vCenterToConnect + '.' + $suffix
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        $vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $Port -WarningAction Continue -ErrorAction Stop
           
    
    }#end of If Method to Connect
    else{
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        $workingLocationNum = ""
        
        $tmpWorkingLocationNum = ""
        
        $Script:WorkingServer = ""
        
        $i = 0

        #MENU SELECT VCENTER
        foreach ($vcServer in $vcServers){
	   
                $vcServerValue = $vcServer
	    
                Write-Output "            [$i].- $vcServerValue ";	
	            $i++	
                }#end foreach	
                Write-Output "            [$i].- Exit this script ";

                while(!(isNumeric($tmpWorkingLocationNum)) ){
	                $tmpWorkingLocationNum = Read-Host "Type the number of vCenter that you want to connect"
                }#end of while

                    $workingLocationNum = ($tmpWorkingLocationNum / 1)

                if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))  ){
	                $Script:WorkingServer = $vcServers[$WorkingLocationNum]
                }
                else{
            
                    Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
                    Exit;
                }#end of else

        #Connect to Vcenter
        $Script:vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $port -WarningAction Continue -ErrorAction Continue
  
    
    }#end of Else Method to Connect

}#End of Function Connect to Vcenter


function AdjustRRLun-IOPSLimit
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateRange(1,1000)]
        [int]$IOPSLimitValue
   
    )

Do {

[int]$userMenuChoice = 0
$lunlist = ""
$waveToAdjust = ""

#MAIN MENU - WHILE YOU DON'T PRESS 4. IT WILL BACK TO MENU      
    Do {
    
    Write-Output "

----------MENU ADJUST ROUND ROBIN IOPS LIMIT----------

The IOPS Limit value will be adjust to: $IOPSLimitValue

1 = Generate Report Before Adjust IOPS Limit
2 = Generate Report After Adjust IOPS LIMIT
3 = Adjusting Round Robin IOPS limit in a Cluster: $Script:WorkingCluster
4 = Exit

------------------------------------------------------"

[int]$userMenuChoice = Read-host -prompt "Select an Option and Press Enter - Only Accept 1,2,3 or 4"

        switch ($userMenuChoice){
        1 {
    
            #Datastores
            $dsNameList = @()
        
            $dsNameList = (Get-Datastore | Where-Object -FilterScript {$PSItem.ExtensionData.Info.Vmfs.Local -eq $false} | Select-Object -ExpandProperty Name | Sort-Object)

            $lunNAAList = @()
        
            foreach ($dsName in $dsNameList)
            {
            
                $dsObj = Get-datastore -Name $dsName
            
                $dsNAA = $dsObj.ExtensionData.Info.Vmfs.Extent[0].DiskName

                $lunNAAList += $dsNAA
                           
            }

            [string]$waveToAdjust = Read-Host "Digite a Onda que será ajustada (Exemplo: Onda1)"

            $csvFile = $Script:pathOutput + "\LUNCONFIG-BEFORE-ADJUST-RR-IOPS-$waveToAdjust-$currentDate.csv"

            #Check to see if the file exists, if it does then overwrite it.
            if (Test-Path $csvfile) {
    
                Write-Output "Overwriting $csvfile ..."
    
                Start-Sleep -Milliseconds 400

                Remove-Item $csvfile -Confirm -Verbose
            }  


        foreach ($esxiHost in $Script:allESXiHosts){
    
            foreach ($lunName in $lunList){
        
                Get-ScsiLun -CanonicalName $lunName -VmHost $esxiHost | Select-Object -Property VmHost,CanonicalName,MultipathPolicy,CommandsToSwitchPath | Export-Csv -NoTypeInformation -Path $csvFile -Append -Verbose
        
            }#end ForeachLuns
    
    
        }#end ForeachHosts

        explorer $Script:pathOutput
    
    }#end of 1
        2 {
    
            #Datastores
            $dsNameList = @()
        
            $dsNameList = (Get-Datastore | Where-Object -FilterScript {$PSItem.ExtensionData.Info.Vmfs.Local -eq $false} | Select-Object -ExpandProperty Name | Sort-Object)

            $lunNAAList = @()
        
            foreach ($dsName in $dsNameList)
            {
            
                $dsObj = Get-datastore -Name $dsName
            
                $dsNAA = $dsObj.ExtensionData.Info.Vmfs.Extent[0].DiskName

                $lunNAAList += $dsNAA
                           
            }



            [string]$waveToAdjust = Read-Host "Digite a Onda que será ajustada (Exemplo: Onda1)"

            $csvFile = $Script:pathOutput + "\LUNCONFIG-AFTER-ADJUST-RR-IOPS-$waveToAdjust-$currentDate.csv"

            #Check to see if the file exists, if it does then overwrite it.
            if (Test-Path $csvfile) {
    
                Write-Output "Overwriting $csvfile ..."
    
                Start-Sleep -Milliseconds 400

                Remove-Item $csvfile -Confirm -Verbose
            }  


            foreach ($esxiHost in $Script:allESXiHosts){
    
                foreach ($lunName in $lunList){
        
                Get-ScsiLun -CanonicalName $lunName -VmHost $esxiHost | Select-Object -Property VmHost,CanonicalName,MultipathPolicy,CommandsToSwitchPath | Export-Csv -NoTypeInformation -Path $csvFile -Append -Verbose
        
                }#end ForeachLuns
    
    
            }#end ForeachHosts

    explorer $Script:pathOutput
    
    }#end of 2
        3 {
        
        #Datastores
        $dsNameList = @()
        
        $dsNameList = (Get-Datastore | Where-Object -FilterScript {$PSItem.ExtensionData.Info.Vmfs.Local -eq $false} | Select-Object -ExpandProperty Name | Sort-Object)

        $lunNAAList = @()
        
        foreach ($dsName in $dsNameList)
        {
            
            $dsObj = Get-datastore -Name $dsName
            
            $dsNAA = $dsObj.ExtensionData.Info.Vmfs.Extent[0].DiskName

            $lunNAAList += $dsNAA
            
        }
        
        [string]$waveToAdjust = Read-Host "Digite a Onda que será ajustada (Exemplo: Onda1)"

        $csvFile = $Script:pathOutput + "\LUNCONFIG-ADJUST-RR-IOPS-$waveToAdjust-$currentDate.csv"

        #Check to see if the file exists, if it does then overwrite it.
        if (Test-Path $csvfile) {
    
            Write-Output "Overwriting $csvfile ..."
    
            Start-Sleep -Milliseconds 400

            Remove-Item $csvfile -Confirm -Verbose
        }  


        foreach ($esxiHost in $Script:allESXiHosts){
    
            foreach ($lunName in $lunList){
        
            Get-ScsiLun -CanonicalName $lunName -VmHost $esxiHost | Set-ScsiLun -CommandsToSwitchPath $IOPSLimitValue -Verbose 
        
        
            }#end ForeachLuns
    
    
        }#end ForeachHosts

        explorer $Script:pathOutput
    
    
    }#end of 3
        4 {
    
    Disconnect-VIServer -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

    Write-Output "You choose finish the Script"
    
    Start-Sleep -Seconds 2
    
    Exit


    }#end of 4
        }#end of switch

    }until($userMenuChoice -lt 1 -or $userMenuChoice -gt 4)#end of Do Until

}while ($userMenuChoice -ne 4)#end of Do While


}#End of Function AdjustRRLun-IOPSLimit

Do
{
 
        $tmpMethodToConnect = Read-Host -Prompt "Type (Manual) if you want to choose vCenter to Connect. Type (Automatic) if you want to Type the Name of vCenter to Connect"

        if ($tmpMethodToConnect -notmatch "^(?:manual\b|automatic\b)"){
    
            Write-Host "You typed an invalid word. Type only (manual) or (automatic)" -ForegroundColor White -BackgroundColor Red
    
        }
        else{
    
            Write-Host "You typed a valid word. I will continue =D" -ForegroundColor White -BackgroundColor DarkBlue
    
        }
    
    }While ($tmpMethodToConnect -notmatch "^(?:manual\b|automatic\b)")


if ($tmpMethodToConnect -match "^\bautomatic\b$"){

    $tmpSuffix = Read-Host "Type the suffix of vCenter that you want to connect (suffix1.domain or suffix2.domain)"

    $tmpVC = Read-Host "Type the hostname of vCenter that you want to connect"

    Connect-ToVcenterServer -vCenterToConnect $tmpVC -suffix $tmpSuffix -methodToConnect Automatic

}
else{

    Connect-ToVcenterServer -methodToConnect $tmpMethodToConnect -VCServers $vcServerList

}

Write-Output "`n"

Write-Host "Select the Cluster that you Want to Connect:" -ForegroundColor DarkBlue -BackgroundColor White

Write-Output "`n"

#CREATE CLUSTER LIST
$VCClusterList = (Get-Cluster | Select-Object -ExpandProperty Name| Sort-Object)

$tmpWorkingClusterNum = ""
        
$WorkingCluster = ""
        
$i = 0
        

#CREATE CLUSTER MENU LIST
    foreach ($VCCluster in $VCClusterList){
	   
        $VCClusterValue = $VCCluster
	    
        Write-Output "            [$i].- $VCClusterValue ";	
	    $i++	
        
        }#end foreach	
        
        Write-Output "            [$i].- Exit this script ";

        while(!(isNumeric($tmpWorkingClusterNum)) ){
	        $tmpWorkingClusterNum = Read-Host "Type vCenter Cluster Number that you want to Adjust Round Robin"
        }#end of while

            $workingClusterNum = ($tmpWorkingClusterNum / 1)

        if(($workingClusterNum -ge 0) -and ($workingClusterNum -le ($i-1))  ){
	        $Script:WorkingCluster = $vcClusterList[$workingClusterNum]
        }
        else{
            
            Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else

$script:allESXiHosts = Get-VMHost -Location $Script:WorkingCluster | Select-Object -ExpandProperty Name | Sort-Object

$tmpIOPSLimitValue = Read-Host "Digite um valor para ajustar o IOPS Limits (Range aceito: 1 a 1000)" 

$intIOPSLimitValue = ($tmpIOPSLimitValue / 1)

AdjustRRLun-IOPSLimit -IOPSLimitValue $intIOPSLimitValue