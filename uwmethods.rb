class Iterator
  def initialize(value)
    @value = value
  end

  def increase
    @value += 1
    "%02d" % [@value]
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
    if File.file?(@input_path)
      @input_is_file = true
    elsif File.directory?(@input_path)
      @input_is_dir = true
    else
      @input_unrecognized = true
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
