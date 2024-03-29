# ReadPsv

A powershell cmdlet to parse the content and calculate the checksum of internal file in a .psv file dumped using [psvgamesd](https://github.com/motoharu-gosuto/psvgamesd) 

## Usage

```
ReadPsv.PS1 -romFile [Path to psv file] [-Extract] [-Details] [-Headered] 
                        [-Normalize] [-Export (gro0 | grw0 | all)] [-Minimal]
                        [-NoHash] [-NoCheckRawZero] [-PartitionInfosOnly]
```

- Extract: Will extract the internal files to the current working directory. This might take anyware around 1.5GB to 3.7GB of space and the files are encrypted.
- Details: Print some debug messages, mainly for development purposes.
- Headered: Use this flag if you're running this on a file that hasn't been stripped by [psvstrip](https://github.com/Kippykip/PSVStrip) when in doubt use this flag.
- Normalized: Use this flag when the original dump contains a writable (aka grw0) partition. This will create a second file (original file name with `_norm.psv` appended) with some variable fields removed from the grw0 partition. I have tried my best to stay as true as possible to an "unplayed/sealed" PSVita game all checksums were recalculated so the partition should act like a valid exFAT partition.
- Minimal: Like the normalized mode but with less intrusive modifications.
- Export: Let you export the `gro0` (rom) partition, `grw0` (writable) partition or `all` (both) as individual files. These files are in the exFAT format and are usable with forensic tools like autopsy.
- NoHash: Skip MD5 hash calculation for inner files. This will significantly increase processing speed if file integrity checking is not needed.
- NoCheckRawZero: Skip the check that make sure all the data in the raw partition is composed of only 0's. Increases processing time a little bit. Do not use if you want to make sure there's not hidden data in the raw partitions.
- PartitionInfosOnly: Use if you just want an overview of all defined partitions in the file. ie: You are not interested in internal file structures details.
- To output to a file instead of the console, use the `6>` redirection operator.

## Fields Affected by the normalization process

See [https://learn.microsoft.com/en-us/windows/win32/fileio/exfat-specification](https://learn.microsoft.com/en-us/windows/win32/fileio/exfat-specification) for the full exFAT specification

- `VolumeSerialNumber` is reset to all 0's for both the main boot sector and the backup boot sector.
- `Main Boot Checksum` and `Backup Boot Checksum` aka sectors 11 and 23 are rewritten with the new checksum, this is due to the fact that the `VolumeSerialNumber` is included in the checksum.
- Primary and Secondary FAT tables are left untouched, it doesn't seem like the PSVita uses them. However this might turn out to be a wrong assumption.
- The first `Allocation Bitmap` is modified to reflect the fact that sector 2,3,4,5,6 are allocated to the `Primary Allocation Bitmap`, `Secondary Allocation Bitmap`, `Up-case Table`, `Root Directory Record`, `SceIoTrash Directory Record` respectively.
- The second `Allocation Bitmap` is left untouched as it doesn't seem to change this also could be a wrong assumption.
- The `Up-case Table` is left untouched, the vita seems to use Microsoft's recommended Up-case Table and I highly doubt this will ever be different.
- The root directory record cluster is changed. I make sure they all start with a `Volume Label` called `exfat` (that's what I saw in an unplayed dump but it seems to be removed when this partition is first written.) Then I just copy paste the `FAT table directory record`, `Primary Allocation bitmap directory record`, `Secondary Allocation bitmap directory record`, `Up-case table directory record`. I assume they always appear in the same order and always allocate the same cluster index (again this might be wrong).
- I remove every file and folder directory records from the root folder and add a single empty folder called `SceIoTrash` (this is the content I see in an unplayed dump). The thing to note here is that all the timestamps on this folder are fixed and faked.
- I reset to 0 all clusters that were originally allocated to files in this partition. Only clusters 2,3,4,5,6 are left as-is although cluster 6 is also all 0's because it represents an empty folder.
- The read only partition (aka gro0) is left as-is.
- The trailing raw (empty) partition is left as-is.

## Minimal mode

- Used mainly to stay as faithful as possible to the original dump. 
- Should be used mainly with sealed dump/unplayed game.
- Same as the above except primary and secondary `Allocation Bitmap` are untouched, the `Root Directory Record` and all file data is left as is.

## Linux users

The code should also work on linux. I can only guarantee that it works on Ubuntu because it is the distro I run but I don't see why it wouldn't run on other distros.

Check out how to install powershell on linux: [https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3)

## Credits

- File formats and other useful information from: [Vita dev wiki](https://playstationdev.wiki/psvitadevwiki/index.php/Main_Page)
