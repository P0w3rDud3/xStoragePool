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

    if ((Get-StoragePool -FriendlyName $storagePoolName -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Verbose "Creating storage pool $storagePoolName"

        $PhysicalDisks = Get-PhysicalDisk | Where {$_.DeviceId -in $diskNumbers}

        New-StoragePool -FriendlyName $storagePoolName `
                        -StorageSubSystemUniqueId (Get-StorageSubSystem -FriendlyName "*pool*").UniqueID `
                        -PhysicalDisks $PhysicalDisks
    }

    if ((Get-VirtualDisk -FriendlyName $virtualDiskName -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Verbose "Creating Virtual Disk $virtualDiskName"

        New-VirtualDisk -FriendlyName $virtualDiskName `
                        -StoragePoolFriendlyName $storagePoolName `
                        -UseMaximumSize `
                        -ProvisioningType Fixed `
                        -ResiliencySettingName Simple

        Write-Verbose "Initializing Disk"

        Initialize-Disk -VirtualDisk (Get-VirtualDisk -FriendlyName $virtualDiskName)
    }

    if((Get-VirtualDisk -FriendlyName $virtualDiskName).OperationalStatus -eq "Detached")
    {
        Write-Verbose "Attaching Virtual Disk"
        Connect-VirtualDisk -FriendlyName $virtualDiskName
    }

    $diskNumber = (Get-VirtualDisk -FriendlyName $virtualDiskName | Get-Disk).Number

    If((Get-Partition -DriveLetter $driveletter -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Verbose "Creating Partition"

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

    $result = $true

    try
    {
        if(Test-Path "$($driveletter):")
        {
            Write-Verbose "Drive $driveLetter found"
        }
        else
        {
            Write-Verbose "Drive $driveLetter not found"
            $result = $false
        }

        if(Get-StoragePool -FriendlyName $storagePoolName -ErrorAction SilentlyContinue)
        {
            Write-Verbose "StoragePool $storagePoolName found"
        }
        else
        {
            Write-Verbose "StoragePool; $storagePoolName not found"
            $result = $false
        }

        if(Get-VirtualDisk -FriendlyName $virtualDiskName -ErrorAction SilentlyContinue)
        {
            Write-Verbose "VirtualDisk $virtualDiskName found"
        }
        else
        {
            Write-Verbose "VirtualDisk $virtualDiskName not found"
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