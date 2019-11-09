#!/usr/bin/ruby

require 'json'
require 'tempfile'
require 'csv'
require 'optparse'
require 'mediainfo'

# This controls option flags
# -p option allows you to select a custom mediaconch policy file - otherwise script uses default
# -e allows you to select a target file extenstion for the script to use.
# If no extenstion is specified it will target the default 'wav' extension. (Not case sensitive)
ARGV.options do |opts|
  opts.on("-p", "--Policy=val", String) { |val| POLICY_FILE = val }
  opts.on("-e", "--Extension=val", String) { |val| TARGET_EXTENSION = val }
  opts.on("-q", "--Quiet") { Quiet = true}
  opts.parse!
end

# set up arrays and variables
@write_to_csv = []
if ! defined? TARGET_EXTENSION
  TARGET_EXTENSION = 'wav'
end

# Start embedded WAV Mediaconch policy section
# Policy derived from MediaConch Public Policies. Original Maintainer Peter B. License: CC-BY-4.0+
mc_policy = <<EOS
<?xml version="1.0"?>
<policy type="and" name="Local Wave Policy" license="CC-BY-4.0+">
  <description>This is the common norm for WAVE audiofiles.&#xD;
Any WAVs not matching this policy should be inspected and possibly normalized to conform to this.</description>
  <policy type="or" name="Signed Integer or Float?">
    <rule name="Is signed Integer?" value="Format_Settings_Sign" tracktype="Audio" occurrence="*" operator="=">Signed</rule>
    <rule name="Is floating point?" value="Format_Profile" tracktype="Audio" occurrence="*" operator="=">Float</rule>
  </policy>
  <policy type="and" name="Audio: Proper resolution?">
    <description>This policy defines audio-resolution values that are proper for WAV.</description>
    <policy type="or" name="Valid samplerate?">
      <description>This was not implemented as rule in order to avoid irregular sampling rates.</description>
      <rule name="Audio is 44.1 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">44100</rule>
      <rule name="Audio is 48 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">48000</rule>
      <rule name="Audio is 88.2 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">88200</rule>
      <rule name="Audio is 96 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">96000</rule>
      <rule name="Audio is 192 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">192000</rule>
      <rule name="Audio is 11 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">11025</rule>
      <rule name="Audio is 22.05 kHz?" value="SamplingRate" tracktype="Audio" occurrence="*" operator="=">22050</rule>
    </policy>
    <policy type="or" name="Valid bit depth?">
      <rule name="Audio is 16 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">16</rule>
      <rule name="Audio is 24 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">24</rule>
      <rule name="Audio is 32 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">32</rule>
      <rule name="Audio is 8 bit?" value="BitDepth" tracktype="Audio" occurrence="*" operator="=">8</rule>
    </policy>
  </policy>
  <policy type="and" name="Is BFW?">
    <rule name="BEXT Exist?" value="Wave/Broadcast extension/" occurrence="*" operator="exists" scope="mmt"/>
  </policy>
  <policy type="and" name="Valid File Size?">
    <rule name="Size Limit" value="FileSize" tracktype="General" occurrence="*" operator="&lt;">4000000000</rule>
  </policy>
  <rule name="Container is RIFF (WAV)?" value="Format" tracktype="General" occurrence="*" operator="=">Wave</rule>
  <rule name="Encoding is linear PCM?" value="Format" tracktype="Audio" occurrence="*" operator="=">PCM</rule>
  <rule name="Audio is 'Little Endian'?" value="Format_Settings_Endianness" tracktype="Audio" occurrence="*" operator="=">Little</rule>
</policy>
EOS
# End embedded WAV Mediaconch policy section

if ! defined? POLICY_FILE
  POLICY_FILE = Tempfile.new('mediaConch')
  POLICY_FILE.write(mc_policy)
  POLICY_FILE.rewind
end

# Function to scan file for mediaconch compliance
def media_conch_scan(input, policy)
  qc_results = []
  policy_path = File.path(policy)
  command = 'mediaconch --Policy=' + '"' + policy_path + '" ' + '"' + input + '"'
  media_conch_out = `#{command}`
  media_conch_out.strip!
  media_conch_out.split('/n').each do |qcline|
    qc_results << qcline
  end
  return qc_results
end

# Functions to scan audio stream characteristics
# Function to get ffprobe json info
def get_ffprobe(input)
  ffprobe_command = 'ffprobe -print_format json -threads auto -show_entries frame_tags=lavfi.astats.Overall.Peak_level,lavfi.aphasemeter.phase -f lavfi -i "amovie=' + "'" + input + "'" + ',astats=reset=1:metadata=1,aphasemeter=video=0"'
  ffprobe_out = JSON.parse(`#{ffprobe_command}`)
end

def get_mediainfo(input)
  mediainfo_out = MediaInfo.from(input)
end

def qc_encoding_history(mediainfo_out)
  enc_hist_error = []
  unless mediainfo_out.general.extra.nil?
    if mediainfo_out.general.extra.bext_present == 'Yes' && mediainfo_out.general.encoded_library_settings
      if mediainfo_out.audio.channels == 1
        mono_count = mediainfo_out.general.encoded_library_settings.scan(/mono/).count
        unless mono_count == 2
          enc_hist_error << "BEXT Coding History channels don't match file"
        end
      end

      if mediainfo_out.audio.channels == 2
        stereo_count = mediainfo_out.general.encoded_library_settings.scan(/stereo/).count
        dual_count = mediainfo_out.general.encoded_library_settings.scan(/dual/).count
        unless stereo_count + dual_count == 2
          enc_hist_error << "BEXT Coding History channels don't match file"
        end
      end
    end
  end
  return enc_hist_error
end

def parse_duration(duration_milliseconds)
  Time.at(duration_milliseconds / 1000).utc.strftime("%H:%M:%S")
end

def parse_ffprobe_peak_levels(ffprobe_data)
  high_db_frames = []
  levels = []
  ffprobe_data['frames'].each do |frames|
    peaklevel = frames['tags']['lavfi.astats.Overall.Peak_level'].to_f
    if peaklevel > -2.0
      high_db_frames << peaklevel
    end
    levels << peaklevel
  end
  return high_db_frames, levels.max
end

def parse_ffprobe_phase(ffprobe_data)
  out_of_phase_frames = []
  ffprobe_data['frames'].each do |frames|
    audiophase = frames['tags']['lavfi.aphasemeter.phase'].to_f
    if audiophase < -0.25
      out_of_phase_frames << audiophase
    end
  end
  return out_of_phase_frames
end


# Make list of inputs
file_inputs = []
ARGV.each do |input|
  # If input is directory, recursively add all files with target extension to target list
  if File.directory?(input)
    targets = Dir["#{input}/**/*.{#{TARGET_EXTENSION.upcase},#{TARGET_EXTENSION.downcase}}"]
    targets.each do |file|
      file_inputs << file
    end
  # If input is file, add it to target list (if extension matches target extension)
  elsif File.extname(input).downcase == '.' + TARGET_EXTENSION.downcase && File.exist?(input)
    file_inputs << input
  else
    puts "Input: #{input} not found!"
  end
end

if file_inputs.empty?
  puts "No targets found!"
  exit
end

file_inputs.each do |fileinput|
  warnings = []
  fileinput = File.expand_path(fileinput)
  ffprobe_out = get_ffprobe(fileinput)
  mediainfo_out = get_mediainfo(fileinput)
  duration_normalized = parse_duration(mediainfo_out.audio.duration)
  encoding_hist_error = qc_encoding_history(mediainfo_out)
  total_frame_count = ffprobe_out['frames'].count
  level_info = parse_ffprobe_peak_levels(ffprobe_out)
  max_level = level_info[1]
  dangerous_levels = level_info[0]
  phase_fails = parse_ffprobe_phase(ffprobe_out)
  media_conch_results = media_conch_scan(fileinput, POLICY_FILE).to_s
  if media_conch_results.include?('pass!')
    media_conch_results = 'PASS'
  else
    warnings << 'MEDIACONCH FAIL'
  end
  if encoding_hist_error.count > 0 
    warnings  << encoding_hist_error
  end
  if dangerous_levels.count > 0
    warnings << 'LEVEL WARNING'
  end
  if phase_fails.count > 50
    warnings << 'PHASE WARNING'
  end
  if defined? Quiet
    if Quiet && warnings.empty?
      puts "QC Pass!"
      exit 0
    elsif Quiet
      puts "QC Fail!"
      puts warnings
      exit 1
    end 
  else
    @write_to_csv << [fileinput, warnings.flatten, duration_normalized, max_level, dangerous_levels.count, phase_fails.count, media_conch_results]
  end
end

timestamp = Time.now.strftime('%Y-%m-%d_%H-%M-%S')
output_csv = ENV['HOME'] + "/Desktop/audioqc-out_#{timestamp}.csv"

CSV.open(output_csv, 'wb') do |csv|
  headers = ['Filename', 'Warnings', 'Duration', 'Peak Level', 'Number of Frames w/ High Levels', 'Number of Phase Warnings', 'MediaConch Policy Compliance']
  csv << headers
  @write_to_csv.each do |line|
    csv << line
  end
end
