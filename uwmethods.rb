# frozen_string_literal: true

# Get OS
if RUBY_PLATFORM.include?('linux')
  LINUX = true
elsif RUBY_PLATFORM.include?('darwin')
  MACOS = true
else
  #others
end



class Iterator
  def initialize(value)
    @value = value
  end

  def increase
    @value += 1
    format('%02d', @value)
  end
end

def preview_camera
  ffmpeg_device_options = []
  if LINUX
    ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
  elsif MACOS
    ffmpeg_device_options += ['-f', 'avfoundation', '-i', 'default']
  end
  ffplay_command = ['ffplay', ffmpeg_device_options].flatten
  system(*ffplay_command)
end

def take_photo(output_name)
  ffmpeg_device_options = []
  ffmpeg_middle_options = []
  if LINUX
    ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
  elsif MAC
    ffmpeg_device_options += ['-f', 'avfoundation', '-i', 'default']
  end
  ffmpeg_command = ['ffmpeg', ffmpeg_device_options, '-window_title "Press Escape When Ready To Continue"', output_name].flatten
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

  def take_photos
    iteration = Iterator.new(1)
    output = [get_output_location, '_', iteration.to_s , '.jpg'].join
    preview_camera
    take_photo(output)
  end
end
