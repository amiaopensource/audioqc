# frozen_string_literal: true

require 'bagit'
require 'mediainfo'

# Get OS
if RUBY_PLATFORM.include?('linux')
  LINUX = true
elsif RUBY_PLATFORM.include?('darwin')
  MACOS = true
end

def preview_camera
  ffmpeg_device_options = []
  ffmpeg_middle_options = ['-vf', 'scale=1280:-2,crop=out_w=800:out_h=800']
  if LINUX
    ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
  elsif MACOS
    ffmpeg_device_options += ['-f', 'avfoundation', '-i', 'default']
  end
  ffplay_command = ['ffplay', ffmpeg_device_options, ffmpeg_middle_options].flatten
  system(*ffplay_command)
end

class MediaObject
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
      `file -b --mime-type #{@input_path}`.strip
    else
      ## Filler for windows
    end
  end

  def get_output_location
    root_name = File.basename(@input_path, '.*')
    out_dir = File.dirname(@input_path)
    "#{out_dir}/#{root_name}"
  end

  # Redo this with actual specs
  def make_derivative
    output = get_output_location
    if @input_is_audio
      output += '.flac'
      system('ffmpeg', '-i', @input_path, '-c:a', 'flac', output)
    elsif @input_is_video
      output += '.mp4'
      system('ffmpeg', '-i', @input_path, '-c:v', 'h264', output)
    end
  end

  def make_metadata
    output = get_output_location
    output_media_info = "#{output}_mediainfo.xml"
    output_mediatrace = "#{output}_mediatrace.xml"
    output_ffprobe = "#{output}_ffprobe.xml"
    if LINUX || MAC
      File.open(output_mediatrace, 'w') { |file| file.write(`mediaconch -mi -mt -fx "#{@input_path}"`) }
      File.open(output_media_info, 'w') { |file| file.write(`mediaconch -mi -fx "#{@input_path}"`) }
      File.open(output_ffprobe, 'w') { |file| file.write(`ffprobe 2> /dev/null "#{@input_path}" -show_format -show_streams -show_data -show_error -show_versions -show_chapters -noprivate -of xml="q=1:x=1"`) }
    end
  end

  def take_photo(output_name)
    ffmpeg_device_options = []
    ffmpeg_middle_options = ['-vframes', '1', '-q:v', '1', '-y', '-vf', 'scale=1280:-2,crop=out_w=800:out_h=800']
    if LINUX
      ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
    elsif MAC
      ffmpeg_device_options += ['-f', 'avfoundation', '-i', 'default']
    end
    ffmpeg_command = ['ffmpeg', ffmpeg_device_options, ffmpeg_middle_options, output_name].flatten
    system(*ffmpeg_command)
  end

  def take_photos
    @iterator = 1 unless defined?(@iterator)
    output = [get_output_location, '_', format('%02d', @iterator), '.jpg'].join
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

  def move_media(destination)
    if File.directory?(destination)
      rsync_command = ['rsync', '--remove-source-files', '-tvPih', @input_path, destination]
      if system(*rsync_command)
        @input_path = "#{destination}/#{File.basename(@input_path)}"
      end
    end
  end

  def structure_package; end
end
