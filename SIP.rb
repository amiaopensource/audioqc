require "./uwmethods.rb"

ARGV.each do |target|
  archival_target = MediaObject.new(target)
  archival_target.make_derivatives
  archival_target.make_metadata
  archival_target.move_to_package
end