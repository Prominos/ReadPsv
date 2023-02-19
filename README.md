# ReadPsv

A powershell cmdlet to parse the content and calculate the checksum of internal file in a .psv file dumped using [psvgamesd](https://github.com/motoharu-gosuto/psvgamesd) 

## Usage

ReadPsv.PS1 -romFile [Path to psv file] [-Extract] [-Details] [-Headered]

- Extract: Will extract the internal files to the current working directory. This might take anyware around 1.5GB to 3.7GB of space and the files are encrypted.
- Details: Print some debug messages, mainly for development purposes.
- Headered: Use this flag if you're running this on a file that hasn't been stripped by [psvstrip](https://github.com/Kippykip/PSVStrip) when in doubt use this flag.

## Credits

- File formats and other useful information from: [Vita dev wiki](https://playstationdev.wiki/psvitadevwiki/index.php/Main_Page)
