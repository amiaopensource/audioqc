# audioqc

Depends on: FFprobe, Mediaconch, Media Info, BWF Metaedit, Ruby

## Set-up

### Windows:
* [Ruby](https://rubyinstaller.org/) will need to be installed if it isn't present already.
* All dependencies will have to be added to the 'Path' and sholuld be the command line version (CLI) of their respective tools
* Mediaconch, Media Info and BWF Metaedit can be downloaded from the [MediaArea](https://mediaarea.net/) website
* FFprobe can be downloaded as part of the [FFmpeg package](https://ffmpeg.org/download.html#build-windows)

### Mac:
* All dependencies can be installed via the [Homebrew package manager](https://brew.sh/)

Usage:  `audioqc.rb [options] TARGET`

### Linux:
* Most dependencies should be installable through the standard package manager.
* For the most up to date versions of Media Area dependencies it is recommended to activate the [MediaArea](https://mediaarea.net/en/Repos) repository

Options: `-h` Help, ` -e` set target extension (for example `-e flac`). Default is wav. `-p` Override the built in mediaconch policy file with a custom file. `-p PATH-TO-POLICY-FILE`. `-q` Quiet mode - does not create CSV, just gives simple pass/fail in terminal. `-m` Scan file metadata (enabled by default). `-s` Scan file signal with ffprobe (enabled by default).

This script can target both directories and single audio files, and will generate basic audio QC reports of to the desktop. Reports contain a warning for high levels, a warning for audio phase, and a Media Conch compliance check. Script has been tested on macOS and Linux.
