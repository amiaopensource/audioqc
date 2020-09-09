# audioqc

## About

This script can target both directories and single audio files, and will generate audio quality control reports to the desktop. Different levels of reports are available through the use of different options. Available information includes:
* Peak and average audio levels
* Number of audio frames exceeding -2.0 dB
* Average audio phase
* Number of audio frames exceeding set limit for poor audio phase
* Wave file conformance check (if input is Wave)
* Scan of embedded coding history to check consistency with file characteristics (If input is BWF using CodingHistory field)
* MediaConch policy conformance check (default is for Wave - optional policy inputs are supported)
* Locations of possible drop-outs (very experimental, suffers from many false positives at this point)

## Set-up
Depends on: ffprobe, MediaConch, MediaInfo, BWF MetaEdit, Ruby

### Windows:
* [Ruby](https://rubyinstaller.org/) will need to be installed if it isn't present already.
* All dependencies will have to be added to the 'Path' and sholuld be the command line version (CLI) of their respective tools
* MediaConch, MediaInfo and BWF MetaEdit can be downloaded from the [MediaArea](https://mediaarea.net/) website
* ffprobe can be downloaded as part of the [FFmpeg package](https://ffmpeg.org/download.html#build-windows)

### Mac:
* All dependencies can be installed via the [Homebrew package manager](https://brew.sh/)

Usage:  `audioqc.rb [options] TARGET`

### Linux:
* Most dependencies should be installable through the standard package manager.
* For the most up to date versions of MediaArea dependencies it is recommended to activate the [MediaArea](https://mediaarea.net/en/Repos) repository

Options: `-h` Help, ` -e` set target extension (for example `-e flac`). Default is wav. `-p` Override the built in mediaconch policy file with a custom file. `-p PATH-TO-POLICY-FILE`. `-q` Quiet mode - does not create CSV, just gives simple pass/fail in terminal. `-m` Scan file metadata (enabled by default). `-s` Scan file signal with ffprobe (enabled by default).
