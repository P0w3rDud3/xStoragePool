function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.UInt32[]]
        $diskNumbers,

        [parameter(Mandatory = $true)]
        [System.String]
        $storagePoolName,

        [parameter(Mandatory = $true)]
        [System.String]
        $virtualDiskName,

        [parameter(Mandatory = $true)]
        [System.String]
        $driveletter
    )

    Try 
    {
        if (Test-Path "$($driveLetter):") 
        {
            Write-Verbose "Volume $driveletter exists"
            @{
                Driveletter = $driveletter
                Mounted   = $true
            }
        }
        else {
             Write-Verbose "Volume $driveletter doesn't exist"
             @{
                DriveLetter = $driveletter
                Mounted   = $false
             }
        }
    }
    Catch 
    {
        throw "An error occured querying the volume $driveLetter. Error: $($_.Exception.Message)"
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.UInt32[]]
        $diskNumbers,

        [parameter(Mandatory = $true)]
        [System.String]
        $storagePoolName,

        [parameter(Mandatory = $true)]
        [System.String]
        $virtualDiskName,

        [parameter(Mandatory = $true)]
        [System.String]
        $driveletter
    )

    Write-Verbose "Creating storage pool $storagePoolName"

    $PhysicalDisks = Get-PhysicalDisk | Where {$_.DeviceId -in $diskNumbers}

    New-StoragePool -FriendlyName $storagePoolName `
                    -StorageSubSystemUniqueId (Get-StorageSubSystem -FriendlyName "*pool*").UniqueID `
                    -PhysicalDisks $PhysicalDisks

    Write-Verbose "Creating Virtual Disk $virtualDiskName"

    New-VirtualDisk -FriendlyName $virtualDiskName `
                    -StoragePoolFriendlyName $storagePoolName `
                    -UseMaximumSize `
                    -ProvisioningType Fixed `
                    -ResiliencySettingName Simple

    Write-Verbose "Initializing Disk"

    Initialize-Disk -VirtualDisk (Get-VirtualDisk -FriendlyName $virtualDiskName)

    Write-Verbose "Creating Partition"

    $diskNumber = (Get-VirtualDisk -FriendlyName $virtualDiskName | Get-Disk).Number

    New-Partition -DiskNumber $diskNumber `
                  -UseMaximumSize `
                  -DriveLetter $driveletter

    Write-Verbose "Formatting volume and assigning driveletter $driveLetter"

    Format-Volume -DriveLetter $driveLetter `
                  -FileSystem NTFS `
                  -NewFileSystemLabel "SQLData" `
                  -Confirm:$False `
                  -Force


}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.UInt32[]]
        $diskNumbers,

        [parameter(Mandatory = $true)]
        [System.String]
        $storagePoolName,

        [parameter(Mandatory = $true)]
        [System.String]
        $virtualDiskName,

        [parameter(Mandatory = $true)]
        [System.String]
        $driveletter
    )

    try
    {
        if(Test-Path "$($driveletter):")
        {
            Write-Verbose "Drive $driveLetter found"
            $result = $true
        }
        else
        {
            Write-Verbose "Drive $driveLetter not found"
            $result = $false
        }
    }
    catch
    {
        throw "An error occured querying the volume $driveLetter. Error: $($_.Exception.Message)"
    }

    $result
}


Export-ModuleMember -Function *-TargetResource