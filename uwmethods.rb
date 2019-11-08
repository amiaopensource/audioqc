# frozen_string_literal: true

require 'bagit'
require 'mediainfo'
require 'pry'

# Get OS
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
      `file -b --mime-type #{@input_path}`.strip
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

  # Redo this with actual specs
  def make_derivative
    paths = get_output_location.insert(2, 'derivatives')
    deriv_dir = paths[0..2].join('/')
    unless File.directory?(deriv_dir)
      Dir.mkdir(deriv_dir)
    end
    output = paths.join('/')
    if @input_is_audio
      output += '.flac'
      command = ['ffmpeg', '-i', @input_path, '-c:a', 'flac', output]
    elsif @input_is_video
      output += '.mp4'
      command = ['ffmpeg', '-i', @input_path, '-c:v', 'h264', output]
    end
    system(*command)
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

def regex_for_sides(input)
  # Checks if file name ends in varios patterns of _side1, -side_a etc.)
  input.gsub(/(_|-)(side|part)(_|-)?(0?[1-9]|[a-b])/,'')
end