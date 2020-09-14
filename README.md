# audioqc

## About

This script can target both directories and single audio files, and will generate audio quality control reports to the desktop. If targeting a directory, it will recursively search that and all subdirectories for all files that match the chosen input extension. (Default is WAV). Different levels of reports are available through the use of different options. Available information includes:
* Peak and average audio levels
* Number of audio frames exceeding user specified limit (defaults to -2.0 dB)
* Average audio phase
* Number of audio frames exceeding user specified limit for poor audio phase
* Wave file conformance check (if input is Wave)
* Scan of embedded coding history to check consistency with file characteristics (if input is BWF using CodingHistory field)
* MediaConch policy conformance check (default is for Wave - optional policy inputs are supported)
* Locations of possible drop-outs (very experimental, suffers from many false positives at this point)

## Set-up
Requires CLI installations of: ffprobe, MediaConch, MediaInfo, BWF MetaEdit, Ruby

### Windows:
* [Ruby](https://rubyinstaller.org/) will need to be installed if it isn't present already.
* All dependencies will have to be added to the 'Path' and should be the command line version (CLI) of their respective tools
* MediaConch, MediaInfo and BWF MetaEdit can be downloaded from the [MediaArea](https://mediaarea.net/) website
* ffprobe can be downloaded as part of the [FFmpeg package](https://ffmpeg.org/download.html#build-windows)

### Mac:
* All dependencies can be installed via the [Homebrew package manager](https://brew.sh/)


### Linux:
* Most dependencies should be installable through the standard package manager.
* For the most up to date versions of MediaArea dependencies it is recommended to activate the [MediaArea](https://mediaarea.net/en/Repos) repository

### Usage:
`audioqc [options] TARGET`
This will result in a CSV output to your desktop. To change default settings, edit the values contained in the associated file `audioqc.config`.

Examples: 
* `audioqc -p 'my-mediaconch-policy.xml' -e flac 'My-Flac-Folder'`
* `audioqc -m -s -b 'My-File.wav'`

__NOTE 1:__ If no output settings are chosen, audioqc will run in with the equivalent of `-m` and `-s` enabled, for signal and technical metadata output.

__NOTE 2:__ If running the QC scan with output for signal information enabled, the scan can take quite a while to run on long or large numbers of files. This is expected and is because the script needs to generate information for every individual audio frame.

Options: 

`-h` Help, 

` -e` set target extension (for example `-e flac`). Default is wav. 

`-p` Override the built in mediaconch policy file with a custom file for example `-p PATH-TO-POLICY-FILE`. 

`-q` Quiet mode - does not create CSV, just gives simple pass/fail in terminal. 

`-a` All. Will output information for all possible settings.

`-m` Scan file technical metadata (enabled by default).

`-s` Scan file signal with ffprobe (enabled by default).

`-b` Scan BEXT metadata for consistency of CodingHistory field

`-d` Scan file for audio dropouts (experimental!)
