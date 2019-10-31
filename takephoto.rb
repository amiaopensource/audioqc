#!/usr/bin/ruby
# frozen_string_literal: true

Script_dir = __dir__

if RUBY_PLATFORM.include?('linux')
  LINUX = true
else
  RUBY_PLATFORM.include?('some mac thing')
  MAC = true
end

def preview_camera
  ffmpeg_device_options = []
  if LINUX
    ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
  elsif MAC
    ffmpeg_device_options += ['-f', 'avfoundation', '-i', 'default']
  end

  ffplay_command = ['ffplay', ffmpeg_device_options].flatten
  system(*ffplay_command)
end

def take_picture(output_info)
  ffmpeg_device_options = []
  ffmpeg_middle_options = []
  ffmpeg_output_options = []
  if LINUX
    ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
  elsif MAC
    ffmpeg_device_options += ['-f', 'avfoundation', '-i', 'default']
  end

  ffmpeg_command = ['ffmpeg', ffmpeg_device_options, ffmpeg_middle_options, ffmpeg_output_options].flatten
end

ARGV.each do |input|
  if File.file?(input)
    output_location = File.dirname(input)
    output_file_name_base = File.basename(input, '.*')
  elsif File.directory(input)
    output_location = input
    puts "Please enter name to be used for picture file(s)"
    output_file_name_base = gets.chomp
  else
    puts "Invlid input: #{input}"
  end
  output_info = [output_location, output_file_name_base]
end
