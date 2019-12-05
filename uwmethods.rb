# frozen_string_literal: true

require 'bagit'
require 'mediainfo'

# Get OS
LINUX = false
MACOS = false
if RUBY_PLATFORM.include?('linux')
  LINUX = true
elsif RUBY_PLATFORM.include?('darwin')
  MACOS = true
end

class Sip
  def move_media_remove(input, destination)
    if File.directory?(destination)
      rsync_command = ['rsync', '-tvPih', input, destination]
      if system(*rsync_command) && 
        @input_path = "#{destination}/#{File.basename(@input_path)}"
      end
    end
  end

  def move_media_keep(input, destination)
    if File.directory?(destination)
      rsync_command = ['rsync', '--remove-source-files', '-tvPih', input, destination]
      if system(*rsync_command) && 
        @input_path = "#{destination}/#{File.basename(@input_path)}"
      end
    end
  end
end

  def get_time
    Time.now.strftime("%H:%M:%S")
  end

  def get_date
    Time.now.strftime("%Y-%m-%d")
  end

class MediaObject < Sip
  def initialize(value)
    @input_path = value
    mime_type = get_mime
    if File.file?(@input_path) && mime_type.include?('audio')
      @input_is_audio = true
    elsif File.file?(@input_path) && mime_type.include?('video')
      @input_is_video = true
    elsif File.directory?(@input_path)
      @input_is_dir = true
    else
      @input_unrecognized = true
    end
  end

  def get_mime
    if LINUX || MACOS
      `file -b --mime-type "#{@input_path}"`.strip
    else
      ## Filler for windows
    end
  end

  def get_output_location
    root_name = File.basename(@input_path, '.*')
    base_dir = File.dirname(@input_path)
    project_dir = regex_for_sides(root_name)
    unless File.directory?("#{base_dir}/#{project_dir}")
      Dir.mkdir("#{base_dir}/#{project_dir}")
    end
    [base_dir, project_dir, root_name]
  end

  def get_derivative_paths
    paths = get_output_location.insert(2, 'derivatives')
    deriv_dir = paths[0..2].join('/')
    unless File.directory?(deriv_dir)
      Dir.mkdir(deriv_dir)
    end
    paths.join('/')
  end

  # Redo this with actual specs
  def make_derivatives
    output = get_derivative_paths
    build_audio_mezzanine_command(output)
    if @input_is_audio
      flac_command = build_flac_command(output)
      ffmpeg_command_mezzanine = build_audio_mezzanine_command(output)
      ffmpeg_command_access = ['ffmpeg', '-i', @input_path, '-c:a', 'libmp3lame', '-write_id3v1', '1', '-id3v2_version', '3', '-dither_method', 'triangular', '-af', 'dynaudnorm=g=81', '-metadata', 'Normalization="ffmpeg dynaudnorm=g=81"', '-qscale:a', '2', output + '.mp3']
      system(*build_audio_mezzanine_command(output))
      system(*flac_command)
    elsif @input_is_video
      ffmpeg_command_access = ['ffmpeg', '-i', @input_path, '-c:v', 'h264', output + '.mp4']
    end
    system(*ffmpeg_command_access)
  end

  def build_audio_mezzanine_command(output)
    mezzanine = output + '_48kHz.wav'
    ['ffmpeg', '-i', @input_path, '-map_metadata', '-1', '-c:a', 'pcm_s24le', '-ar', '48000', '-af', 'dynaudnorm=g=81', '-write_bext', '1', build_bext, mezzanine].flatten
  end

  def build_flac_command(output)
    mezzanine = output + '_48kHz.wav'
    flac_out = "#{File.dirname(output)}/"
    ['flac', '--best', '--keep-foreign-metadata', "--tag=Description=Decode with --keep-foreign-metadata to access embedded BEXT chunk", '--preserve-modtime', '--verify', '--delete-input-file', '--output-prefix', flac_out, mezzanine]
  end

  def grab_bext
    media_data = MediaInfo.from(File.path(@input_path))
    originator = media_data.general.archival_location
    originator_reference = media_data.general.extra.producer_reference
    description = media_data.general.description
    coding_history = media_data.general.encoded_library_settings.gsub(" / ", "\n")
    [description, originator, coding_history, originator_reference]
  end

  def update_coding_hist(target)
    bext_data = grab_bext
    new_hist = bext_data[1] + "\\nA=PCM,F=48000,W=24,M=#{get_channels},T=FFmpeg"
    system('bwfmetaedit',"--history=#{new_hist}", target)
  end

  def build_bext
    bext_data = grab_bext
    new_hist = bext_data[2] + "\nA=PCM,F=48000,W=24,M=#{get_channels},T=FFmpeg"
    new_description = bext_data[0] + "-LOUDNESS NORMALIZED MEZZANINE"
    bext_meta_command = []
    bext_meta_command << "description=#{new_description}"
    bext_meta_command << "originator=#{bext_data[3]}"
    bext_meta_command << "originator_reference=#{bext_data[1]}"
    bext_meta_command << "origination_date=#{get_date}"
    bext_meta_command << "origination_time=#{get_time}"
    bext_meta_command << "origination_time=#{get_time}"
    bext_meta_command << "coding_history=#{new_hist}"
    bext_meta_command << "IARL=#{bext_data[3]}"
    bext_meta_command.flat_map {|meta| ['-metadata', meta]}
  end

  def make_metadata
    paths = get_output_location.insert(2, 'file_metadata')
    meta_dir = paths[0..2].join('/')
    output = paths.join('/')
    unless File.directory?(meta_dir)
      Dir.mkdir(meta_dir)
    end
    output_media_info = "#{output}_mediainfo.xml"
    output_mediatrace = "#{output}_mediatrace.xml"
    output_ffprobe = "#{output}_ffprobe.xml"
    if LINUX || MACOS
      File.open(output_mediatrace, 'w') { |file| file.write(`mediaconch -mi -mt -fx "#{@input_path}"`) }
      File.open(output_media_info, 'w') { |file| file.write(`mediaconch -mi -fx "#{@input_path}"`) }
      File.open(output_ffprobe, 'w') { |file| file.write(`ffprobe 2> /dev/null "#{@input_path}" -show_format -show_streams -show_data -show_error -show_versions -show_chapters -noprivate -of xml="q=1:x=1"`) }
    end
  end

  def get_channels
    media_data = MediaInfo.from(File.path(@input_path))
    if media_data.audio.channels == 1
      channels = 'mono'
    elsif media_data.audio.channels == 2
      channels = 'stereo'
    elsif media_data.audio.channels == 4
      channels = 'quad'
    else
      channels = media_data.audio.channels.to_s
    end
  end

  def take_photo(output_name)
    ffmpeg_device_options = []
    ffmpeg_middle_options = ['-vframes', '1', '-q:v', '1', '-y']
    if LINUX
      ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
    elsif MACOS
      ffmpeg_device_options += ['-f', 'avfoundation', '-video_size', '640x480', '-i', 'default']
    end
    ffmpeg_command = ['ffmpeg', ffmpeg_device_options, ffmpeg_middle_options, output_name].flatten
    system(*ffmpeg_command)
  end

  def take_photos
    paths = get_output_location
    @iterator = 1 unless defined?(@iterator)
    output = [paths.join('/'), '_', format('%02d', @iterator), '.jpg'].join
    preview_camera
    take_photo(output)
    puts 'Take another picture? Enter y for yes, r for retake and anything else to finish'
    user_response = gets.chomp
    if user_response == 'y'
      @iterator += 1
      take_photos
    elsif user_response == 'r'
      take_photos
    end
  end

  def move_associated
    #
  end

  def move_to_package
    paths = get_output_location
    destination = paths[0..1].join('/')
    if File.directory?(destination)
      rsync_command = ['rsync', '--remove-source-files', '-tvPih', @input_path, destination]
    end
    system(*rsync_command)
  end
end

def preview_camera
  ffmpeg_device_options = []
  ffmpeg_middle_options = []
  if LINUX
    ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
  elsif MACOS
    ffmpeg_device_options += ['-f', 'avfoundation', '-video_size' , '640x480', '-i', 'default']
  end
  ffplay_command = ['ffplay', ffmpeg_device_options, ffmpeg_middle_options].flatten
  system(*ffplay_command)
end

def regex_for_sides(input)
  # Checks if file name ends in varios patterns of _side1, -side_a etc.)
  input.gsub(/(_|-)(side|part)(_|-)?(0?[1-9]|[a-b])/,'')
end