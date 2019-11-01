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

class Media_Object
  def initialize(value)
    @system = get_os
    @input_path = value
    if @system == 'linux' || @system == 'mac'
      mime_type = `file -b --mime-type #{@input_path}`.strip
    end
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

  def make_derivative
    root_name = File.basename(@input_path, '.*')
    out_dir = File.dirname(@input_path)
    if @input_is_audio
      output = "#{out_dir}/#{root_name}.flac"
      system('ffmpeg', '-i', @input_path.to_s, '-c:a', 'flac', output.to_s)
    end
  end

  def test
    if @input_is_file
      puts 'FILE'
    elsif @input_is_dir
      puts 'DIR'
    else
      puts 'DUNNO!'
    end
  end
end
