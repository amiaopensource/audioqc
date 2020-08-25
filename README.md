# audioqc

## audioqc

Depends on: FFprobe, Mediaconch, Media Info

Needed Gems: mediainfo

Usage:  `audioqc.rb [options] TARGET`

Options: `-h` Help, ` -e` set target extension (for example `-e flac`). Default is wav. `-p` Override the built in mediaconch policy file with a custom file. `-p PATH-TO-POLICY-FILE`. `-q` Quiet mode - does not create CSV, just gives simple pass/fail in terminal. `-m` Scan file metadata (enabled by default). `-s` Scan file signal with ffprobe (enabled by default).

This script can target both directories and single audio files, and will generate basic audio QC reports of to the desktop. Reports contain a warning for high levels, a warning for audio phase, and a Media Conch compliance check. Script has been tested on macOS and Linux.
