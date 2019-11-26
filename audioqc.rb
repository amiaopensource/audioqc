#!/usr/bin/ruby
# frozen_string_literal: true

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
  opts.on('-p', '--Policy=val', String) { |val| POLICY_FILE = val }
  opts.on('-e', '--Extension=val', String) { |val| TARGET_EXTENSION = val }
  opts.on('-q', '--Quiet') { Quiet = true }
  opts.on('-m', '--Meta-only') { Meta_only = true}
  opts.parse!
end

# set up arrays and variables
TARGET_EXTENSION = 'wav' unless defined? TARGET_EXTENSION

# Start embedded WAV Mediaconch policy section
# Policy derived from MediaConch Public Policies. Original Maintainer Peter B. License: CC-BY-4.0+
mc_policy = <<~EOS
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

unless defined? POLICY_FILE
  POLICY_FILE = Tempfile.new('mediaConch')
  POLICY_FILE.write(mc_policy)
  POLICY_FILE.rewind
end

class QcTarget
  def initialize(value)
    @input_path = value
    @warnings = []
  end

  # Function to scan file for mediaconch compliance
  def media_conch_scan(policy)
    @qc_results = []
    policy_path = File.path(policy)
    command = 'mediaconch --Policy=' + '"' + policy_path + '" ' + '"' + @input_path + '"'
    media_conch_out = `#{command}`
    media_conch_out.strip!
    media_conch_out.split('/n').each {|qcline| @qc_results << qcline}
    @qc_results = @qc_results.to_s
    if @qc_results.include?('pass!')
      @qc_results = 'PASS'
    else
      @warnings << 'MEDIACONCH FAIL'
    end
  end

  # Functions to scan audio stream characteristics
  # Function to get ffprobe json info
  def get_ffprobe
    ffprobe_command = 'ffprobe -print_format json -threads auto -show_entries frame_tags=lavfi.astats.Overall.Peak_level,lavfi.aphasemeter.phase -f lavfi -i "amovie=' + "'" + @input_path + "'" + ',astats=reset=1:metadata=1,aphasemeter=video=0"'
    @ffprobe_out = JSON.parse(`#{ffprobe_command}`)
    @total_frame_count = @ffprobe_out['frames'].count
  end

  def get_mediainfo
    @mediainfo_out = MediaInfo.from(@input_path)
    @duration_normalized = Time.at(@mediainfo_out.audio.duration / 1000).utc.strftime('%H:%M:%S')
  end

  def qc_encoding_history
    @enc_hist_error = []
    unless @mediainfo_out.general.extra.nil?
      if @mediainfo_out.general.extra.bext_present == 'Yes' && @mediainfo_out.general.encoded_library_settings
        signal_chain_count = @mediainfo_out.general.encoded_library_settings.scan(/A=/).count
        if @mediainfo_out.audio.channels == 1
          unless @mediainfo_out.general.encoded_library_settings.scan(/mono/).count == signal_chain_count
            @enc_hist_error << "BEXT Coding History channels don't match file"
          end
        end

        if @mediainfo_out.audio.channels == 2
          stereo_count = @mediainfo_out.general.encoded_library_settings.scan(/stereo/).count
          dual_count = @mediainfo_out.general.encoded_library_settings.scan(/dual/).count
          unless stereo_count + dual_count == signal_chain_count
            @enc_hist_error << "BEXT Coding History channels don't match file"
          end
        end
      end
    else
      @enc_hist_error << "Encoding history not present"
    end
    @warnings << encoding_hist_error if @encoding_hist_error.count > 0
  end

  def find_peaks
    @high_db_frames = []
    @levels = []
    @ffprobe_out['frames'].each do |frames|
      peaklevel = frames['tags']['lavfi.astats.Overall.Peak_level'].to_f
      @high_db_frames << peaklevel if peaklevel > -2.0
      @levels << peaklevel
      @max_level = @levels.max
    end
    @warnings << 'LEVEL WARNING' if @high_db_frames.count > 0
  end

  def find_phase
    @out_of_phase_frames = []
    @ffprobe_out['frames'].each do |frames|
      audiophase = frames['tags']['lavfi.aphasemeter.phase'].to_f
      @out_of_phase_frames << audiophase if audiophase < -0.25
    end
    @warnings << 'PHASE WARNING' if @out_of_phase_frames.count > 50
  end

  def output_csv_line
    [@input_path, @warnings.flatten, @duration_normalized, @max_level, @high_db_frames.count, @out_of_phase_frames.count, @qc_results]
  end
end

# Make list of inputs
file_inputs = []
@write_to_csv = []
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
  puts 'No targets found!'
  exit
end

file_inputs.each do |fileinput|
  target = QcTarget.new(File.expand_path(fileinput))
  target.get_ffprobe
  target.get_mediainfo
  target.find_peaks
  target.find_phase
  target.media_conch_scan(POLICY_FILE)
  if defined? Quiet
    if Quiet && warnings.empty?
      puts 'QC Pass!'
      exit 0
    elsif Quiet
      puts 'QC Fail!'
      puts warnings
      exit 1
    end
  else
    @write_to_csv << target.output_csv_line
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
