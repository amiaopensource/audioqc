#!/usr/bin/ruby

if RUBY_PLATFORM.include?('linux')
  Linux = true
else
  RUBY_PLATFORM.include?('some mac thing')
  MAC = true
end
ffmpeg_device_options = []

if Linux
  ffmpeg_device_options += [ '-f', 'v4l2', '-i' ,'/dev/video0' ]
end

ffplay_command = [ 'ffplay', ffmpeg_device_options ].flatten
system(*ffplay_command)
