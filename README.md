# audioqc

## About
This tool is intended to assist with batch/collection level quality control of archival WAV files digitized from analog sources. It can target directories and single audio files, and will generate audio quality control reports in CSV to the desktop or user specified location. It scans for peak/average audio levels, files with 'hot' portions exceeding a user set limit, audio phase, file integrity (from embedded MD5 checksums), bext metadata conformance and mediaconch policy conformance. It also can generate images of the audio spectrum and waveform of each input file.

Development note: This tool was rewritten in 2025 to simplify usage, code and dependencies. For the legacy code, see [here](https://github.com/amiaopensource/audioqc/tree/new-code-base/deprecated) or the [final release](https://github.com/amiaopensource/audioqc/releases/tag/2025-05-23) containing the previous code.


## Setup

Requires Ruby, CLI versions of FFmpeg/FFprobe, Mediainfo and Mediaconch.
Configurations, such as dependency paths can be set in the associated CSV file.

### Mac:
* All dependencies and audioqc scripts can be installed via the [Homebrew package manager](https://brew.sh/)
* Once Homebrew is installed, run the commands `brew tap amiaopensource/amiaos` followed by `brew install audioqc` to complete the install process.

### Windows:
* [Ruby](https://rubyinstaller.org/) will need to be installed if it isn't present already.
* All dependencies will have to be added to the 'Path' (or have their locations noted in the configuration file) and should be the command line version (CLI) of their respective tools
* MediaConch, MediaInfo and BWF MetaEdit can be downloaded from the [MediaArea](https://mediaarea.net/) website
* ffprobe can be downloaded as part of the [FFmpeg package](https://ffmpeg.org/download.html#build-windows)


### Linux:
* Most dependencies should be installable through the standard package manager.
* For the most up to date versions of MediaArea dependencies it is recommended to activate the [MediaArea](https://mediaarea.net/en/Repos) repository

## Usage:
Usage: `audioqc [options] TARGET(s)` Target can be either individual files, or a directory, or a combination of the two. This will result in a CSV output to your desktop.
Available options are:

    -o, --output=val                 Optional output path for CSV results file
    -c, --conch=val                  Path to optional mediaconch policy XML file
    -j, --jpg                        Create visualizations of input files (waveform and spectrum)

Congiguration of this tool can be done via the associated `settings.csv` file. Configurable options include settings for what the tools considers 'out of range' for volume and phase, as well as paths for output, mediaconch policies and dependencies.

Note: The scan can take a while to run on large batches of files - this is expected!

## Maintainers
Andrew Weaver (@privatezero)
Susie Cummings (@susiecummings)
