param(
    [Parameter(Mandatory=$true)][String]$romFile,
    [Parameter(HelpMessage="Extract Files")]
    [switch]$Extract = $False,
    [Parameter(HelpMessage="Print Debug Messages")]
    [switch]$Details = $False,
    [switch]$Headered = $False,
    [switch]$Normalize = $False,
    [switch]$Minimal = $False,
    [Parameter(Mandatory=$False)][String]$ExportPart
)
$ErrorActionPreference = "Stop"

$MAGIC_VALUE = "Sony Computer Entertainment Inc."
$MAGIC_OFFSET = 0;
$MAGIC_SIZE = 0x20;
$MAGIC_BLOCK_TRAILER = 0xAA55
$JUMP_BOOT = 0x9076EB
$EXTFAT_SIG = "EXFAT   "

$EXFAT_VOLUME_LABEL_RECORD = [byte]0x83, 5, 0x65, 0, 0x78, 0, 0x66, 0, 0x61, 0, 0x74, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
$SCE_IO_TRASH_DIR_RECORD = [byte]0x85, 2, 0x26, 2, 0x16, 0, 0, 0, 0xD5,0xAA, 0x56, 0x52, 0xD5, 0xAA, 0x56, 0x52, 0xD5, 0xAA, 0x56, 0x52, 0, 0, 0x80, 0x80, 0x80, 0, 0, 0, 0, 0, 0, 0, 0xC0, 3, 0, 0xA, 0xF, 0x23, 0, 0, 0, 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0x80, 0, 0, 0, 0, 0, 0, 0xC1, 0, 0x53, 0, 0x63, 0, 0x65, 0, 0x49, 0, 0x6F, 0, 0x54, 0, 0x72, 0, 0x61, 0, 0x73, 0, 0x68, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


function ReadString([int]$offset, [int]$length, $source = $block, $unicode = $False)
{
    if ($unicode)
    {
        return [System.Text.Encoding]::Unicode.GetString($source, $offset, $length);
    }
    else
    {
        return [System.Text.Encoding]::ASCII.GetString($source, $offset, $length);
    }
}

function Read2($offset, $source = $block)
{
    $low = $source[$offset] 
    $high =  $source[$offset + 1]
    $val = $high
    $val = $val -as [int]
    $val = $val -band 0xFF
    $val = $val -shl 8
    $val = $val + $low
    return $val
}

function Read4($offset, $source = $block)
{
    $b3 = $source[$offset];
    $b2 = $source[$offset + 1];
    $b1 = $source[$offset + 2];
    $b0 = $source[$offset + 3];

    #Write-Host $b3
    #Write-Host $b2
    #Write-Host $b1
    #Write-Host $b0

    $b3 = $b3 -as [long]
    $b3 = $b3 -band 0xFF

    #Write-Host $([String]::Format("{0:X}",$b3))

    $b2 = $b2 -as [long]
    $b2 = $b2 -band 0xFF
    $b2 = $b2 -shl 8

    #Write-Host $([String]::Format("{0:X}",$b2))

    $b1 = $b1 -as [long]
    $b1 = $b1 -band 0xFF
    $b1 = $b1 -shl 16

    #Write-Host $([String]::Format("{0:X}",$b1))

    $b0 = $b0 -as [long]
    $b0 = $b0 -band 0xFF
    $b0 = $b0 -shl 24

    #Write-Host $([String]::Format("{0:X}",$b0))

    $val = $b3 -bor $b2 -bor $b1 -bor $b0;
    return $val;
}

function Read8($offset, $source = $block)
{
    $b7 = $source[$offset];
    $b6 = $source[$offset + 1];
    $b5 = $source[$offset + 2];
    $b4 = $source[$offset + 3];
    $b3 = $source[$offset + 4];
    $b2 = $source[$offset + 5];
    $b1 = $source[$offset + 6];
    $b0 = $source[$offset + 7];

    #Write-Host $b3
    #Write-Host $b2
    #Write-Host $b1
    #Write-Host $b0

    $b7 = $b7 -as [long]
    $b7 = $b7 -band 0xFF

    $b6 = $b6 -as [long]
    $b6 = $b6 -band 0xFF
    $b6 = $b6 -shl 8

    $b5 = $b5 -as [long]
    $b5 = $b5 -band 0xFF
    $b5 = $b5 -shl 16

    $b4 = $b4 -as [long]
    $b4 = $b4 -band 0xFF
    $b4 = $b4 -shl 24

    $b3 = $b3 -as [long]
    $b3 = $b3 -band 0xFF
    $b3 = $b3 -shl 32

    #Write-Host $([String]::Format("{0:X}",$b3))

    $b2 = $b2 -as [long]
    $b2 = $b2 -band 0xFF
    $b2 = $b2 -shl 40

    #Write-Host $([String]::Format("{0:X}",$b2))

    $b1 = $b1 -as [long]
    $b1 = $b1 -band 0xFF
    $b1 = $b1 -shl 48

    #Write-Host $([String]::Format("{0:X}",$b1))

    $b0 = $b0 -as [long]
    $b0 = $b0 -band 0xFF
    $b0 = $b0 -shl 56

    #Write-Host $([String]::Format("{0:X}",$b0))

    $val = $b7 -bor $b6 -bor $b5 -bor $b4 -bor $b3 -bor $b2 -bor $b1 -bor $b0;
    return $val;
}

function ReadBlock($blockNum)
{
    if ($Headered)
    {
        $blockNum = $blockNum + 1;
    }
    $x = $fs.Seek($blockNum * 512, [System.IO.SeekOrigin]::Begin)
    $x = $fs.Read($block, 0 ,$block.Length);
    $curBlock = $blockNum;
}

function ReadCluster($index)
{
    
    $clusterOffset = $heapOffsetBytes + ($index-2)*$clusterSize

    $x = $fs.Seek($clusterOffset, [System.IO.SeekOrigin]::Begin);
    $x = $fs.Read($cluster, 0 ,$cluster.Length);
    $curCluster = $index
}

function CheckAndPrint($label, $val, $cond)
{
    Write-Host -NoNewline "$($label) $($val) ("
    if ($cond)
    {
        Write-Host -NoNewline -ForegroundColor Green "OK"
    }
    else
    {
        Write-Host -NoNewline -ForegroundColor Red "Bad"
    }
    Write-Host ")"
    
}

function GetPartitionUsageName($pcode)
{
    if ($pcode -eq 0)
    {
        $val = "Code: 0 | Format: Raw | Backing: EMMC | Info: Empty Partition"
    }
    elseif ($pcode -eq 1)
    {
        $val = "Code: 1 | Format: Raw | Backing: EMMC | Info: First EMMC Partition"
    }
    elseif ($pcode -eq 2)
    {
        $val = "Code: 2 | Format: Raw | Backing: EMMC | Info: SLB2 Bootloaders"
    }
    elseif ($pcode -eq 3)
    {
        $val = "Code: 3 | Name: os0 | Format: FAT16 | Backing: EMMC | Info: Main OS Files (kernel and user libs)"
    }
    elseif ($pcode -eq 0xE)
    {
        $val = "Code: 0xE | Name: pd0 | Format: exFAT | Backing: EMMC | Info: Welcome Park and intro video"
    }
    elseif ($pcode -eq 0xC)
    {
        $val = "Code: 0xC | Name: sa0 | Format: FAT16 | Backing: EMMC | Info: Fonts and handwriting"
    }
    elseif ($pcode -eq 6)
    {
        $val = "Code: 6 | Name: tm0 | Format: FAT16 | Backing: EMMC | Info: npdrm Partition"
    }
    elseif ($pcode -eq 0xB)
    {
        $val = "Code: 0xB | Name: ud0 | Format: FAT16 | Backing: EMMC | Info: Update Partition"
    }
    elseif ($pcode -eq 7)
    {
        $val = "Code: 7 | Name: ur0 | Format: exFAT | Backing: EMMC | Info: User Partition"
    }
    elseif ($pcode -eq 8)
    {
        $val = "Code: 8 | Name: ux0 | Format: exFAT | Backing: Memory Card | Info: Memory card storage"
    }
    elseif ($pcode -eq 5)
    {
        $val = "Code: 5 | Name: vd0 | Format: FAT16 | Backing: EMMC | Info: Registry and Error History"
    }
    elseif ($pcode -eq 4)
    {
        $val = "Code: 4 | Name: vs0 | Format: FAT16 | Backing: EMMC | Info: Rest of the OS"
    }
    elseif ($pcode -eq 9)
    {
        $val = "Code: 9 | Name: gro0 | Backing: Game Cart | Info: Game Read only partition"
    }
    elseif ($pcode -eq 0xA)
    {
        $val = "Code: 0xA | Name: grw0 | Backing: Game Cart | Info: Game Read and write partition"
    }
    elseif ($pcode -eq 0xD)
    {
        $val = "Code: 0xD | Name: None | Format: Raw | Backing: Game Cart | Info: Empty Partition"
    }
    else
    {
        $val = "Invalid ($($pcode))"
    }

    return $val;
}

function GetPartitionTypeName($pType)
{
    if ($pType -eq 6)
    {
        return "FAT16 (6)"
    }
    elseif ($pType -eq 7)
    {
        return "exFAT (7)"
    }
    elseif ($pType -eq 0xDA)
    {
        return "Raw (0xDA)"
    }
    else
    {
        return "Invalid"
    }
}

function GetTimestamp($bytes)
{
    $seconds = ($bytes -band 0x1F) * 2;
    $minutes = ($bytes -shr 5) -band 0x3F
    $hours = ($bytes -shr 11) -band 0x1F
    $day = ($bytes -shr 16) -band 0x1F
    $month = ($bytes -shr 21) -band 0xF
    $year = (($bytes -shr 25) -band 0x7F) + 1980

    return [String]::Format("{0:0000}/{1:00}/{2:00} {3:00}:{4:00}:{5:00}", $year, $month, $day, $hours, $minutes, $seconds);
}

function GetDirectoryEntryTypeName($typeCode, $typeImportance, $typeCategory)
{
    if ($typeImportance.Contains("0") -and $typeCategory.Contains("0"))
    {
        #Critical Primary Records
        if ($typeCode -eq 1)
        {
            return "Allocation Bitmap"
        }
        elseif ($typeCode -eq 2)
        {
            return "Up-case Table"
        }
        elseif ($typeCode -eq 3)
        {
            return "Volume Label"
        }
        elseif ($typeCode -eq 5)
        {
            return "File"
        }
        else
        {
            return "Invalid"
        }
    }
    elseif ($typeImportance.Contains("1") -and $typeCategory.Contains("0"))
    {
        #Benign Primary
        if ($typeCode -eq 0)
        {
            return "Volume GUID"
        }
        elseif ($typeCode -eq 1)
        {
            return "TexFAT Padding"
        }
        else
        {
            return "Invalid"
        }
    }
    elseif ($typeImportance.Contains("0") -and $typeCategory.Contains("1"))
    {
        #Critical Secondary
        if ($typeCode -eq 0)
        {
            return "Stream Extension"
        }
        elseif ($typeCode -eq 1)
        {
            return "File Name"
        }
        else
        {
            return "Invalid"
        }
    }
    else
    {
        #Benign Secondary
        if ($typeCode -eq 0)
        {
            return "Vendor Extension"
        }
        elseif($typCode -eq 1)
        {
            return "Vendor Allocation";
        }
        else
        {
            return "Invalid"
        }
    }
}

function ReadGeneralFlags($flags, $se = $false)
{
    if ($Details)
    {

        if (($flags -band 1) -eq 0)
        {
            Write-Host "Allocation Possible: No (0)"
        }
        else
        {
            Write-Host "Allocation Possible: Yes (1)"
        }

        if (($flags -band 2) -eq 0)
        {
            Write-Host "No FAT Chain: No (0) [Cluster Chain According to FAT]"
        }
        else
        {
            Write-Host "No FAT Chain: Yes (1) [Contiguous Clusters]"
        }

    }

    if (($flags -band 2) -eq 0 )
    {
        #Write-Host "No FAT Chain: No (0) [Cluster Chain According to FAT]"
        if ($se)
        {
            $Global:curFile.Contiguous = $false
        }

    }
    else
    {
        #Write-Host "No FAT Chain: Yes (1) [Contiguous Clusters]"
        if ($se)
        {
            $Global:curFile.Contiguous = $true
        }
    }
}

function ReadFileAttributes($flags)
{
    if (($flags -band 1) -ne 0)
    {
        if($Details)
        {
            Write-Host "Read Only File"
        }
    }
   

    if (($flags -band 2) -ne 0)
    {
        if ($Details)
        {
            Write-Host "Hidden File"
        }
    }

    if (($flags -band 4) -ne 0)
    {
        if ($Details)
        {
            Write-Host "System File"
        }
    }

    if (($flags -band 0x10) -ne 0)
    {
        if ($Details)
        {
            Write-Host "This is a directory"
        }
        $Global:curFile.IsDirectory = $true
    }
    else
    {
        $Global:curFile.IsDirectory = $false
    }

    if (($flags -band 0x20) -ne 0)
    {
        if ($Details)
        {
            Write-Host "File has changed since last backup"
        }
    }
    
}

function ReadFileDirectoryRecord($offset)
{
    $secondaryCount = $cluster[$offset + 1];
    $setChecksum = Read2 -offset $($offset + 2) -source $cluster
    $fileAttributes = Read2 -offset $($offset + 4) -source $cluster
    $createTimestamp = Read4 -offset $($offset + 8) -source $cluster
    $lastModifiedTimestamp = Read4 -offset $($offset + 12) -source $cluster
    $lastAccessedTimestamp = Read4 -offset $($offset + 16) -source $cluster
    $create10msIncrement = $cluster[$offset + 20];
    $lastModified10msIncrement = $cluster[$offset + 21];
    $createUtcOffset = $cluster[$offset + 22];
    $lastModifyUtcOffset = $cluster[$offset + 23];
    $lastAccessedUtcOffset = $cluster[$offset + 24];

    if ($Details)
    {
        Write-Host "Number of directory records following this one: $($secondaryCount)"
        Write-Host ([String]::Format("Directory record set checksum 0x{0:X4}", $setChecksum))
    }

    ReadFileAttributes -flags $fileAttributes

    if ($Details)
    {
        Write-Host "Date Created: $(GetTimestamp -bytes $createTimestamp)"
        Write-Host "Last Modified: $(GetTimestamp -bytes $lastModifiedTimestamp)"
        Write-Host "Last Accessed: $(GetTimestamp -bytes $lastAccessedTimestamp)"
    }

    return $secondaryCount
}

function ReadUpCaseTableDirectoryRecord($offset)
{
    $tableChecksum = Read4 -offset $($offset + 4) -source $cluster
    $firstCluster = Read4 -offset $($offset + 20) -source $cluster
    $clusterOS = $heapOffsetBytes + ($firstCluster-2) * $clusterSize
    $dataLength = Read8 -offset $($offset + 24) -source $cluster

    if ($Details)
    {
        Write-Host ([String]::Format("Table Checksum: 0x{0:X8}", $tableChecksum))
        Write-Host $([String]::Format("First Cluster: {0} (0x{1:X})", $firstCluster, $clusterOS))
        Write-Host "Data length: $($dataLength) bytes"
    }
}

function ReadStreamExtensionDirectoryRecord($offset)
{
    $generalSecondaryFlags = $cluster[$offset + 1];
    $nameLength = $cluster[$offset + 3];
    $nameHash = Read2 -offset $($offset + 4) -source $cluster
    $validDataLength = Read8 -offset $($offset + 8) -source $cluster
    $firstCluster = Read4 -offset $($offset + 20) -source $cluster
    #$firstCluster = $firstCluster + 2;
    $clusterOS = $heapOffsetBytes + ($firstCluster-2) * $clusterSize
    $dataLength = Read8 -offset $($offset + 24) -source $cluster
    

    ReadGeneralFlags -flags $generalSecondaryFlags -se $true

    if ($Details)
    {
        Write-Host "File Name Length: $($nameLength)"
        Write-Host ([String]::Format("Name Hash: 0x{0:X4}", $nameHash))
        Write-Host "Valid data length: $($validDataLength) bytes"
        Write-Host "Total data length: $($dataLength) bytes"
        Write-Host $([String]::Format("First Cluster: {0} (0x{1:X})", $firstCluster, $clusterOS))
    }

    $Global:curFile.Cluster = $firstCluster
    $Global:curFile.FileOffset = $clusterOS
    $Global:curFile.ValidDataLength = $validDataLength
    $Global:curFile.DataLength = $dataLength

}

function ReadVolumeLabelDirectoryRecord($offset)
{
    $characterCount = $cluster[$offset + 1];
    $volumeLabel = ReadString -offset $($offset+2) -source $cluster -unicode $true -length $($characterCount*2)
    if ($Details)
    {
        Write-Host "Volume Label: $($volumeLabel)"
    }
}

function ReadFileNameDirectoryRecord($offset)
{
    $generalSecondaryFlags = $cluster[$offset + 1];
    $filename = ReadString -offset $($offset + 2) -length 30 -source $cluster -unicode $true
    ReadGeneralFlags -flags $generalSecondaryFlags
    if ($Details)
    {
        Write-Host "Filename: $($filename)"
    }

    return $filename
}

function InternalFileHash($offset, $length, $algorithm)
{
    #Write-Host ([String]::Format("Calculating Hash for 0x{0:X} length: {1}", $offset, $length));
    $fileBuf = [byte[]]::new($length)
    $x = $fs.Seek($offset, [System.IO.SeekOrigin]::Begin);
    $read = 0;
    while ($read -lt $length)
    {
        $x = $fs.Read($fileBuf, $read, $fileBuf.Length)
        $read = $read + $x
    }
    $memStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList $fileBuf, $False
    Get-FileHash -InputStream $memStream -Algorithm $algorithm
}

function DumpFile($filename, $offset, $length)
{
    $fileBuf = [byte[]]::new($length)
    $x = $fs.Seek($offset, [System.IO.SeekOrigin]::Begin);
    $read = 0;
    while ($read -lt $length)
    {
        $x = $fs.Read($fileBuf, $read, $fileBuf.Length)
        $read = $read + $x
    }
    $tpDir =  $dumpDir + "\" + $Global:dir
    $diTpDir = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $tpDir
    if (-Not $diTpDir.Exists)
    {
        $diTpDir.Create();
    }
    $dumpFileName =  $dumpDir + "\" + $Global:dir + "\" + $filename
    $fsOut = [System.IO.File]::Create($dumpFileName)
    $fsOut.Write($fileBuf, 0, $fileBuf.Length)
    $fsOut.Close();
}

function ReadAllocationBitmapDirectoryRecord($offset)
{
    $bitmapFlags = $cluster[$offset + 1] -band 1
    if ($bitmapFlags -eq 0)
    {
        $bitmapFlags = "First Allocation Bitmap (0)"
    }
    else
    {
        $bitmapFlags = "Second Allocation Bitmap (1)"
    }
    $firstCluster = Read4 -offset $($offset + 20) -source $cluster
    $clusterOS = $heapOffsetBytes + ($firstCluster-2) * $clusterSize
    $dataLength = Read8 -offset $($offset + 24) -source $cluster

    if($Details)
    {
        Write-Host $bitmapFlags
        Write-Host $([String]::Format("First Cluster: {0} (0x{1:X})", $firstCluster, $clusterOS))
        Write-Host "Data length: $($dataLength) bytes"
    }
}

function ReadDirectoryRecord($offset)
{
    $entryType = $cluster[$offset]
    $Global:nextOffset = 32

    if ($entryType -eq 0)
    {
        return $False
    }
    
    $typeCode = $entryType -band 0x1F
    if (($entryType -band 0x20) -ne 0)
    {
        $typeImportance = "Benign (1)"
    }
    else
    {
        $typeImportance = "Critical (0)"
    }
    if (($entryType -band 0x40) -ne 0)
    {
        $typeCategory = "Secondary (1)"
    }
    else
    {
        $typeCategory = "Primary (0)"
    }

    if ($entryType -band 0x80 -eq 0)
    {
        $inUse = "No (0)"
    }
    else
    {
        $inUse = "Yes (1)"
    }

    $typeName =  GetDirectoryEntryTypeName -typeCode $typeCode -typeImportance $typeImportance -typeCategory $typeCategory

    if ($Details)
    {
        Write-Host ([String]::Format("Entry Type: {0:X}", $entryType));
        Write-Host "In use: $($inUse)"
        Write-Host "Type Code: $($typeName) ($($typeCode))"
        Write-Host "Type Importance: $($typeImportance)"
        Write-Host "Type Category: $($typeCategory)"
    }
    #if ($typeName -eq "File Name")
    #{
    #    $Global:nextOffset = ReadFileDirectoryRecordSet -offset $offset
    #}
    if ($typeName -eq "File")
    {
        ReadFileDirectoryRecordSet -offset $offset
    }
    #elseif ($typeName -eq "Stream Extension")
    #{
    #    ReadStreamExtensionDirectoryRecord -offset $offset
    #}
    elseif ($typeName -eq "Allocation Bitmap")
    {
        ReadAllocationBitmapDirectoryRecord -offset $offset
    }
    elseif ($typeName -eq "Volume Label")
    {
        ReadVolumeLabelDirectoryRecord -offset $offset
    }
    elseif ($typeName -eq "Up-Case Table")
    {
        ReadUpCaseTableDirectoryRecord -offset $offset
    }
    if ($Details)
    {
        Write-Host
    }

    return $true
}

function GetHumanReadableBytes($num)
{
    $num = $num -as [Decimal]

    if (($num / (1024*1024*1024)) -ge 1.0)
    {
        $ret = $($num / (1024*1024*1024))
        $ret = [System.Math]::Round($ret, 2, [System.MidpointRounding]::AwayFromZero)
        return ([String]::Format("{0,-6} GB", $ret))
    }

    if (($num / (1024*1024)) -ge 1.0)
    {
        $ret = $($num / (1024*1024))
        $ret = [System.Math]::Round($ret, 2, [System.MidpointRounding]::AwayFromZero)
        return ([String]::Format("{0,-6} MB", $ret))
    }

    if (($num / (1024)) -ge 1.0)
    {
        $ret = $($num / (1024))
        $ret = [System.Math]::Round($ret, 2, [System.MidpointRounding]::AwayFromZero)
        return ([String]::Format("{0,-6} KB", $ret))
    }
}

function ReadFileDirectoryRecordSet($offset)
{
    $secondaryCount = ReadFileDirectoryRecord($offset)
    if ($Details)
    {
        Write-Host
    }
    ReadStreamExtensionDirectoryRecord -offset $($offset + 32)
    if ($Details)
    {
        Write-Host
    }
    $secondaryCount = $secondaryCount - 1
    $sb = New-Object -TypeName System.Text.StringBuilder


    for ($i = 0; $i -lt $secondaryCount; $i++)
    {
        $fn = ReadFileNameDirectoryRecord -offset $($offset + 64 + $i*32)
        if ($Details)
        {
            Write-Host
        }
        $x = $sb.Append($fn);
    }

    $ffname = $($sb.ToString().Trim("`0"))

    if ($Details)
    {
        Write-Host "Full File Name: $($ffname)"
    }

    $Global:curFile.FileName = $ffname
    $Global:lstCurrDir.Add($Global:curFile.Clone())
    $Global:currFile = @{}

    $retVal = $(64 + $secondaryCount*32)

    $Global:nextOffset = $retVal
}

function ReadDirectory($offset, $dirName)
{
    $dirEntryOS = 0;
    ReadCluster -index $offset
    [System.Collections.ArrayList]$Global:lstCurrDir = @();
    $Global:curDir.Enqueue($dirName)
    $Global:dir = $dirName;


    while (ReadDirectoryRecord -offset $dirEntryOS)
    {
        #Write-Host "Nextoffset $($Global:nextOffset)"
        $dirEntryOS = $dirEntryOS + $Global:nextOffset;
        #Write-Host "Cluster offset: $($dirEntryOS) / $($clusterSize)"
    }

    Write-Host "==========================================================================================================================="
    Write-Host "Listing for $($dirName) directory"
    Write-Host "==========================================================================================================================="
    Write-Host ([String]::Format("{0,-65}{1,-36}{2}", "File Name", "MD5", "Size"))
    Write-Host "---------------------------------------------------------------------------------------------------------------------------"

    for ($i = 0; $i -lt $Global:lstCurrDir.Count; $i++)
    {
        $cur = $Global:lstCurrDir[$i];

        if ($cur.IsDirectory)
        {
            Write-Host -ForegroundColor Cyan "$($cur.FileName) <DIR>"
            $cur.ParentDir = $dirName
            $Global:stack.Push($cur)
        }
        else
        { 
            if ($cur.Contiguous)
            {
                $md5 =  $(InternalFileHash -offset $cur.FileOffset -length $cur.ValidDataLength -algorithm "MD5").Hash
                if ($Extract)
                {
                    DumpFile -filename $cur.FileName -offset $cur.FileOffset -length $cur.ValidDataLength
                }
                $hum = GetHumanReadableBytes -num $cur.ValidDataLength
                Write-Host ([String]::Format("{0,-60} {1}     {2,-9} B | {3}", $($cur.FileName), $($md5), $($cur.ValidDataLength), $hum)); 
            }
            else
            {
                Write-Host $cur.FileName
            }
        }
    }

    $x = $Global:curDir.Dequeue()
    
    Write-Host
}

function GetDirname()
{
    $sb = New-Object -TypeName System.Text.StringBuilder
    $cloned = $Global:curDir.Clone();
    for ($i = 0; $i -lt $cloned.Count; $i++)
    {
        $x = $sb.Append($cloned.Dequeue());
    }
    return $sb.ToString() + "\";
}

function ReadAllDirs($start)
{
    $flag = $true

    while (($Global:stack.Count -gt 0) -or $flag)
    {
        if ($flag)
        {
            $flag = $false
            $clustOS = $start
            $dirName = "\"
        }
        else
        {
            $cur = $Global:stack.Pop()
            $clustOS = $cur.Cluster;
            if ($cur.ParentDir -eq "\")
            {
                $dirName = $cur.ParentDir + $cur.FileName;
            }
            else
            {
                $dirName = $cur.ParentDir + "\" + $cur.FileName;
            }
        }
        ReadDirectory -offset $clustOS -dirName $dirName 
          
     }
}

function ReadPartitionEntry($offset)
{
    $global:partitionOffset = Read4 -offset $offset;

    if ($global:partitionOffset -eq 0)
    {
        return $false
    }

    $global:partitionSize = Read4 -offset $($offset + 4);
    $global:partitionCode = $block[$($offset+8)]
    $global:pCodeName = GetPartitionUsageName -pcode $global:partitionCode
    $global:partitionType = $block[$($offset+9)]
    $global:pTypeName = GetPartitionTypeName -pType $global:partitionType
    $global:pActive = $block[$($offset+0xA)]
    if ($global:pActive -eq 0)
    {
        $global:pActiveText = "Inactive (0)"
    }
    elseif ($global:pActive -eq 1)
    {
        $global:pActiveText = "Active (1)"
    }
    else
    {
        $global:pActiveText = "Invalid"
    }

    return $true

}

function PrintPartitionInfos($num)
{
    Write-Host "Partition #$($num)"
    Write-Host ([String]::Format("Partition offset: Block 0x{0:X4} (0x{1:X8})", $global:partitionOffset, $global:partitionOffset * 512));
    Write-Host ([String]::Format("Partition Size: {0} blocks ({1} bytes)", $global:partitionSize, $global:partitionSize * 512));
    CheckAndPrint -label "Partition code:" -val $global:pCodeName -cond $(-not $global:pCodeName.Contains("Invalid"))
    CheckAndPrint -label "Partition Type:" -val $global:pTypeName -cond $($global:pTypeName -ne "Invalid")
    CheckAndPrint -label "Partition Active?:" -val $pActiveText -cond $($pActiveText -ne "Invalid")
    Write-Host
}

function ReadExFATPartition($num)
{
    $Global:nextOffset = 32;
    $Global:curFile = @{};
    $Global:stack = New-Object -TypeName System.Collections.Stack
    $Global:curDir = New-Object -TypeName System.Collections.Queue
    $Global:curDir.Enqueue("$(pwd)");
    ReadBlock -blockNum $global:partitionOffset;
    $volumeOS = $global:partitionOffset * 512
    if ($Headered)
    {
        $volumeOS = $volumeOS + 512
    }
    $jmpCode = Read4 -offset 0
    $jmpCode = $jmpCode -band 0xFFFFFF
    $fsSig = ReadString -offset 3 -length 8
    $partOffset = Read8 -offset 64
    $partOffsetBytes = $partOffset * 512
    if ($Headered)
    {
        $partOffsetBytes = $partOffsetBytes + 512
    }
    $volumeSize = Read8 -offset 72
    $fatOffset = Read4 -offset 80
    $fatLen = Read4 -offset 84
    $heapOffset = Read4 -offset 88
    $clusterCnt = Read4 -offset 92
    $rootDirCluster = Read4 -offset 96
    $bytesPerSector = 1 -shl $block[108]
    $sectorsPerCluster = 1 -shl $block[109]
    $volumeSerial = Read4 -offset 100
    
    $fsRevision = Read2 -offset 104
    $volFlags = Read2 -offset 106
    $percentInUse = $block[112];
    $heapOffsetBytes = $heapOffset * $bytesPerSector + $volumeOS
    $clusterSize = $bytesPerSector * $sectorsPerCluster
    $rootDirOffsetBytes = $heapOffsetBytes + (($rootDirCluster - 2) * $clusterSize);
    if ($percentInUse -eq 255)
    {
        $percentInUse = "Unavailable (0xFF)"
    }
    if ($global:curWritable)
    {
        $global:volumeSerialOffset = $partOffsetBytes + 100;
        $global:writablePartOffset = $partOffsetBytes;
        $global:writablePartLen = $volumeSize * $bytesPerSector;
        $global:writableRootDirOS = $heapOffsetBytes + (($rootDirCluster - 2) * $clusterSize);
        $global:writableHeapOS = $heapOffset * $bytesPerSector + $volumeOS;
        $global:writableHeapLen = $clusterCnt * $sectorsPerCluster * $bytesPerSector;
    }
    $bootSig = Read2 -offset 510
    $cluster = [Byte[]]::new($sectorsPerCluster * $bytesPerSector);
    [uint32]$calcChecksum = BootChecksum -offset $volumeOS -zeroOut $false


    Write-Host "Reading Partition #$($num)"
    CheckAndPrint -label "Jump Boot Code: " -val ([string]::Format("0x{0:X3}", $jmpCode)) -cond ($jmpCode -eq $JUMP_BOOT)
    CheckAndPrint -label "File System Signature: " -val $fsSig -cond ($fsSig -eq $EXTFAT_SIG)
    Write-Host ([String]::Format("PartitionOffset: Block 0x{0:X} (0x{1:X})", $partitionOffset, $partOffsetBytes))
    Write-Host ([String]::Format("VolumeSize: {0} sectors ({1} bytes)", $volumeSize, $volumeSize * $bytesPerSector))
    Write-Host ([String]::Format("FAT Offset: Sector 0x{0:X} (0x{1:X})", $fatOffset, ($fatOffset + $partitionOffset) * $bytesPerSector))
    Write-Host ([String]::Format("FAT Length: {0} sectors ({1} bytes)", $fatLen, $fatLen * $bytesPerSector))
    Write-Host ([String]::Format("ClusterHeapOffset: Sector 0x{0:X} (0x{1:X})", $heapOffset, ($heapOffset + $partitionOffset) * $bytesPerSector))
    Write-Host ([String]::Format("ClusterCount: {0} clusters ({1} bytes)", $clusterCnt, $clusterCnt * $sectorsPerCluster * $bytesPerSector))
    Write-Host ([String]::Format("FirstClusterOfRootDirectory: 0x{0:X} (0x{1:X})", $rootDirCluster, $rootDirOffsetBytes))
    Write-Host ([String]::Format("VolumeSerialNumber: 0x{0:X8}", $volumeSerial))
    Write-Host ([String]::Format("FileSystemRevision: 0x{0:X4}", $fsRevision))
    if ($volFlags -band 1 -ne 0)
    {
        Write-Host "ActiveFAT: Secondary (1)"
    }
    else
    {
        Write-Host "ActiveFAT: Primary (0)"
    }
    Write-Host "VolumeDirty?: $(($volFlags -band 2 -ne 0) -as [bool])"
    Write-Host "MediaFailure?: $(($volFlags -band 4 -ne 0) -as [bool])"
    Write-Host "ClearToZero: $(($volFlags -band 8 -ne 0))"
    Write-Host "BytesPerSector $($bytesPerSector)"
    Write-Host "SectorsPerCluster $($sectorsPerCluster)"
    CheckAndPrint -label "NumberOfFats:" -val $block[110] -cond $($block[110] -eq 1 -or $block[110] -eq 2)
    Write-Host ([String]::Format("DriveSelect: 0x{0:X}", $block[111]))
    Write-Host "PercentInUse: $($percentInUse)"
    CheckAndPrint -label "BootSignature:" -val $([String]::Format("0x{0:X4}", $bootSig)) -cond $($bootSig -eq $MAGIC_BLOCK_TRAILER)
    Write-Host ([String]::Format("Calculated Boot Sector Checksum: 0x{0:X8}", $calcChecksum));
    Write-Host

    ReadAllDirs -start $rootDirCluster
}

function CheckAllZeros([long]$offset, [long]$len)
{
    $x = $fs.Seek($offset, [System.IO.SeekOrigin]::Begin);
    $i = $i -as [long]
    for ($i = 0; $i -lt $len; $i++)
    {
        $b = $fs.ReadByte();
        if ($b -ne 0)
        {
            return $false
        }
    }
    return $true
}

function BootChecksum([long]$offset, [bool]$zeroOut=$true)
{
    [uint32]$NumberOfBytes = 512 * 11;
    [uint32]$Checksum = 0;
    [uint32]$Index = 0;

    $x = $fs.Seek($offset, [System.IO.SeekOrigin]::Begin);
    $buffer = [Byte[]]::new($NumberOfBytes);

    $x = $fs.Read($buffer,0,$buffer.Length)

    if ($zeroOut)
    {
        $buffer[100] = 0;
        $buffer[101] = 0;
        $buffer[102] = 0;
        $buffer[103] = 0;
    }

    for ($Index; $Index -lt $NumberOfBytes; $Index++)
    {
        if (($Index -eq 106) -or ($Index -eq 107) -or ($Index -eq 112))
        {
            continue;
        }
        $theByte = $buffer[$Index];
        $theByte = $theByte -as [uint32]
        $theShift = $Checksum -shr 1;
        $theShift = $theShift -as [uint32]
        [uint32]$ph = 0x80000000L

        if ($Checksum -band 1)
        {
            #Write-Host -NoNewline ([string]::Format("0x{0:X8} + 0x{1:X8} + 0x{2:X8} = ", $ph, $theShift, $theByte))
            $Checksum = $theShift + $theByte + $ph  
        }
        else
        {
            #Write-Host -NoNewline ([string]::Format("0x{0:X8} + 0x{1:X8} = ", $theShift, $theByte))
            $Checksum = $theShift + $theByte;
        }
        #Write-Host ([string]::Format("0x{0:X8}", $Checksum));
    }

    return $Checksum;
}

function ExportPartition([long]$offset, [long]$len, [string]$name)
{
    $x = $fs.Seek($offset, [System.IO.SeekOrigin]::Begin);

    $inFile = $romFile.Substring($romFile.LastIndexOf("\"), $($romFile.LastIndexOf(".") - $romFile.LastIndexOf("\")));
    $firom = New-Object -TypeName System.IO.FileInfo -ArgumentList "$($romFile)";
    $fi = New-Object -TypeName System.IO.FileInfo -ArgumentList "$($firom.Directory)\$($inFile).$($name).img";
    $fos = $fi.Create();
    [long]$totalCount = 0
    $count = 0
    $buffer = [byte[]]::new(64*1024)
    while ($totalCount -lt $len)
    {
        $count = $fs.Read($buffer, 0, $buffer.Length)
        $totalCount = $totalCount + $count;
        $fos.Write($buffer, 0, $count);
    }
    $fos.Close();
}

if ($romFile.Contains("\")) {
[System.IO.FileInfo]$fi = New-Object System.IO.FileInfo -ArgumentList "$($romFile)";
} else {
[System.IO.FileInfo]$fi = New-Object System.IO.FileInfo -ArgumentList "$(pwd)\$romFile";
}

if (-not [String]::IsNullOrEmpty($ExportPart) -and $ExportPart -ne "gro0" -and $ExportPart -ne "grw0" -and $ExportPart -ne "all")
{
    Write-Error "Unrecognized argument: $($ExportPart) for parameter -ExportPath valid values are gro0, grw0 or all"
    exit
}

$curBlock = -1;
$block = New-Object "Byte[]" 512

[System.IO.FileStream]$fs = $fi.OpenRead();
    ReadBlock -blockNum 0

$magic = ReadString -offset $MAGIC_OFFSET -length $MAGIC_SIZE
$version = Read4 -offset 0x20
$size = Read4 -offset 0x24
$global:writablePartOffset = 0




$blocTrailer = Read2 -offset 0x1FE
$dumpDir = "$(pwd)\Dump"

if ($Extract)
{
    $diDump = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $dumpDir
    if (-not $diDump.Exists)
    {
        $diDump.Create();
    }
}



CheckAndPrint -label "Magic String:" -cond $($MAGIC_VALUE -eq $magic) -val $magic
Write-Host "Version: $($version)"
Write-Host ([String]::Format("Size: {0} blocks ({1} bytes)", $size, $size * 512));
CheckAndPrint -label "Block Trailer:" -cond $($MAGIC_BLOCK_TRAILER -eq $blocTrailer) -val ([String]::Format("0x{0:X4}", $blocTrailer))
Write-Host

$peos = 0x50
$peNum = 1
while (ReadPartitionEntry -offset $peos)
{
    PrintPartitionInfos -num $peNum

    if ($global:pCodeName.Contains("grw0") -and $($ExportPart -eq "grw0" -or $ExportPart -eq "all"))
    {
        Write-Host "Found grw0 partition. Exporting..."
        ExportPartition -offset $($global:partitionOffset * 512) -len $($global:partitionSize * 512) -name "grw0"
    }
    elseif ($global:pCodeName.Contains("gro0") -and $($ExportPart -eq "gro0" -or $ExportPart -eq "all"))
    {
        Write-Host "Found gro0 partition. Exporting..."
        ExportPartition -offset $($global:partitionOffset * 512) -len $($global:partitionSize * 512) -name "gro0"
    }

    $peNum++
    $peos = $peos + 17
}

$peNum--;
$peos = 0x50;

for ($i = 1; $i -le $peNum; $i++)
{
    ReadBlock -blockNum 0
    $x = ReadPartitionEntry -offset $peos
    if ($global:pCodeName.Contains("grw0"))
    {
        $global:curWritable = $true;
    }
    else
    {
        $global:curWritable = $false;
    }
    if ($global:partitionType -eq 7)
    {
        
        ReadExFATPartition -num $i
    }
    elseif ($global:partitionType -eq 0xDA)
    {
        Write-Host "Reading Partition #$($i) (RAW) @ 0x$([String]::Format("{0:X} Size: {1} bytes", $global:partitionOffset * 512, $global:partitionSize * 512))"
        $az = CheckAllZeros -offset $($global:partitionOffset * 512) -len $($global:partitionSize * 512);

        if ($az)
        {
            Write-Host "Partition is composed only of zeroes."
        }
        else
        {
            Write-Host "Partition contains some meaningfull data."
        }
    }

    Write-Host 
    Write-Host "///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    Write-Host
    $peos = $peos + 17;

}

if ($($Normalize -or $Minimal) -and $global:writablePartOffset)
{
    Write-Host
    Write-Host "==========================================================================================================================="
    if ($Minimal)
    {
      Write-Host  "Normalizing Dump (Minimal Change Mode)"
    }
    else
    {
        Write-Host "Normalizing Dump (Normal Mode)"
    }
    Write-Host "==========================================================================================================================="
    Write-Host

    $x = $fs.Seek($offset, [System.IO.SeekOrigin]::Begin);
    $inFile = $romFile.Substring($romFile.LastIndexOf("\"), $($romFile.LastIndexOf(".") - $romFile.LastIndexOf("\")));
    $firom = New-Object -TypeName System.IO.FileInfo -ArgumentList "$($romFile)";
    if ($Minimal)
    {
        $fi = New-Object -TypeName System.IO.FileInfo -ArgumentList "$($firom.Directory)\$($inFile)_min.psv";
    }
    else
    {
        $fi = New-Object -TypeName System.IO.FileInfo -ArgumentList "$($firom.Directory)\$($inFile)_norm.psv";
    }
    Write-Host "Writing to $($fi.Name)"
    $fos = $fi.Create();
    $numRomBlocks = $global:writablePartOffset / $block.Length
    Write-Host "Copying gro0 partition, this may take a while..."
    for ($i=0; $i -lt $numRomBlocks; $i++)
    {
        ReadBlock -blockNum $i
        $fos.Write($block, 0, $block.Count);
    }
    
    $numRamBlocks = $global:writablePartLen / $block.Length
    $rootDirIdx = $global:writableRootDirOS / $block.Length - $numRomBlocks
    $allocTable1Idx = $global:writableHeapOS / $block.Length - $numRomBlocks
    Write-Host "Normalizing and writing grw0 partition..."

    for ($i=0; $i -lt $numRamBlocks; $i++)
    {
        ReadBlock -blockNum $($i + $numRomBlocks);
        if ($i -eq 0)
        {
            Write-Host "Zeroing out volume serial number";
            $block[100] = 0;
            $block[101] = 0;
            $block[102] = 0;
            $block[103] = 0;
            Write-Host -NoNewline "Calculating new boot sector checksum... "
            [uint32]$cs = BootChecksum -offset $global:writablePartOffset
            Write-Host ([String]::Format("0x{0:X8}", $cs));  
        }
        elseif ($i -eq 11)
        {
            Write-Host "Writing new checksum in the Main Boot Checksum sector...";
            $byte0 = $cs -band 0xFF;
            $byte1 = ($cs -shr 8) -band 0xFF
            $byte2 = ($cs -shr 16) -band 0xFF
            $byte3 = ($cs -shr 24) -band 0xFF

            for ($j=0; $j -lt $block.Length; $j = $j + 4)
            {
                $block[$j] = $byte0;
                $block[$j+1] = $byte1;
                $block[$j+2] = $byte2;
                $block[$j+3] = $byte3;
            }
        }
        elseif ($i -eq 12)
        {
            Write-Host "Zeroing out volume serial number of backup boot sector..."
            $block[100] = 0;
            $block[101] = 0;
            $block[102] = 0;
            $block[103] = 0;
            Write-Host -NoNewline "Calculating new backup boot sector checksum... "
            [uint32]$bcs = BootChecksum -offset $($global:writablePartOffset+12*512)
            Write-Host ([String]::Format("0x{0:X8}", $bcs));
        }
        elseif ($i -eq 23)
        {
            Write-Host "Writing new checksum in the Backup Boot Checksum sector...";
            $byte0 = $bcs -band 0xFF;
            $byte1 = ($bcs -shr 8) -band 0xFF
            $byte2 = ($bcs -shr 16) -band 0xFF
            $byte3 = ($bcs -shr 24) -band 0xFF

            for ($j=0; $j -lt $block.Length; $j = $j + 4)
            {
                $block[$j] = $byte0;
                $block[$j+1] = $byte1;
                $block[$j+2] = $byte2;
                $block[$j+3] = $byte3;
            }
        }
        elseif ($i -eq $allocTable1Idx -and -not $Minimal)
        {
            Write-Host "Rewriting Allocation table #1..."
            $block[0] = 0x1F
            for ($j=1; $j -lt $block.Length; $j++)
            {
                $block[$j] = 0;
            }
        }
        elseif ($i -eq $rootDirIdx -and -not $Minimal)
        {
            Write-Host "Removing unpredictable directory entries..."
            $de = [Byte[][]]::new(5);
            $de[0] = [Byte[]]::new(32);
            $de[1] = [Byte[]]::new(32);
            $de[2] = [Byte[]]::new(32);
            $de[3] = [Byte[]]::new(32);
            $de[4] = [Byte[]]::new(32);

            for ($outer = 0; $outer -lt $de.Length; $outer++)
            {
                $idx = 0;
                for ($inner = $outer*32; $inner -lt $($outer+1)*32; $inner++)
                {
                    $de[$outer][$idx] = $block[$inner];
                    $idx++;
                }
            }

            if ($de[0][0] -ne 0x83)
            {
                Write-Host "Partition doesn't start with volume label: exfat...";
                Write-Host "Writing volume label: exfat";
                for ($j = 0; $j -lt $de[0].Length; $j++)
                {
                    $block[$j] = $EXFAT_VOLUME_LABEL_RECORD[$j];
                }
            }
            else
            {
                for ($j = 0; $j -lt $de[0].Length; $j++)
                {
                    $block[$j] = $de[0][$j];
                }
                $de[0] = $de[1];
                $de[1] = $de[2];
                $de[2] = $de[3];
                $de[3] = $de[4];
                $de[4] = [byte[]]::new(32);
             
            }


            for ($outer = 0; $outer -lt $de.Length; $outer++)
            {
                $idx = 0;
                if ($de[$outer][0] -eq 0x85 -or $de[$outer][0] -eq 0)
                {
                    break;
                }

                #start at 2nd directory entry
                for ($inner = $($outer+1)*32; $inner -lt $($outer+2)*32; $inner++)
                {
                    $block[$inner] =  $de[$outer][$idx];
                    $idx++;
                }
            }

            $idx = 0
            Write-Host "Writing empty SceIoTrash folder..."
            $limit = $inner + 96;
            for ($inner; $inner -lt $limit; $inner++)
            {
                $block[$inner] =  $SCE_IO_TRASH_DIR_RECORD[$idx]
                $idx++;
            }

            for ($inner; $inner -lt $block.Length; $inner++)
            {
                $block[$inner] = 0;
            }

           
        }
        if ($i -gt $rootDirIdx -and -not $Minimal)
        {
            for ($j = 0; $j -lt $block.Length; $j++)
            {
                $block[$j] = 0
            }
        }
        

        $fos.Write($block, 0, $block.Count);
    }

    Write-Host "Writing Empty Partition"
    $emptyPartOffset = $($global:writablePartOffset + $global:writablePartLen)
    $numEmptyBlocks = $($($fs.Length - $emptyPartOffset) / $block.Length);
    for ($i=0; $i -lt $numEmptyBlocks; $i++)
    {
        ReadBlock -blockNum $($i + $emptyPartOffset / $block.Length)
        $fos.Write($block, 0, $block.Count);
    }

    $fos.Close();
}