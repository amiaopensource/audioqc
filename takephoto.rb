#!/usr/bin/ruby
# frozen_string_literal: true

Script_dir = __dir__

if RUBY_PLATFORM.include?('linux')
  LINUX = true
else
  RUBY_PLATFORM.include?('some mac thing')
  MAC = true
end
ffmpeg_device_options = []

def run_camera(mode)
  if LINUX
    ffmpeg_device_options += ['-f', 'v4l2', '-i', '/dev/video0']
  elsif MAC
    ffmpeg_device_options += ['-f', 'avfoundation', '-i', 'default']
  end

  if mode == 'ffplay'
    ffplay_command = ['ffplay', ffmpeg_device_options].flatten
    system(*ffplay_command)
  end
end
