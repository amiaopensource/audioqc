# frozen_string_literal: true

class Iterator
  def initialize(value)
    @value = value
  end

  def increase
    @value += 1
    format('%02d', @value)
  end
end

def get_os
  if RUBY_PLATFORM.include?('linux')
    system = 'linux'
  elsif RUBY_PLATFORM.include?('darwin')
    system = 'mac'
  end
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
    system = get_os
    if ['linux', 'mac'].include?(system)
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
end
