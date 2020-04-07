#!/usr/bin/ruby

require 'optparse'

options = []
ARGV.options do |opts|
  opts.on('-e', '--embed') { options << 'embed' }
  opts.on('-b', '--burn') { options << 'burn' }
  opts.parse!
end

if RUBY_PLATFORM.include?('mingw32')
  OsType = 'windows'
else
  OsType = 'notwindows'
end

@vidTargets = []
@subTargets = []
inputs = []

if OsType == 'windows'
  FfmpegPath = "#{__dir__}/ffmpeg.exe"
else
  FfmpegPath = 'ffmpeg'
end

def checkMime(targetFile)
  if OsType == 'windows'
    if File.extname(targetFile).downcase == '.vtt' || File.extname(targetFile).downcase == '.srt'
      mimeType = 'text/plain'
    else
      mimeType = 'video'
    end
  else
    mimeType =  `file --b --mime-type "#{targetFile}"`.strip
  end
  @subTargets << targetFile if mimeType == 'text/plain'
  @vidTargets << targetFile if mimeType.include?('video')
end

def getPaths(video)
  outputPath = File.dirname(video) + '/' + File.basename(video,".*")
end

def normalizePaths(path)
  pathNorm = path.gsub('\\','/')
  pathNorm.gsub!('C:','C\\\\\\:')
  pathNorm.gsub!(',','\\,')
  File.path(pathNorm)
end

def burnSubs(video,subPath)
  outputPath = getPaths(video) + '_burntsubs.mp4'
  subPath = normalizePaths(subPath)
  `"#{FfmpegPath}" -i "#{File.path(video)}" -c:v libx264 -pix_fmt yuv420p -c:a aac -crf 25 -movflags +faststart -vf yadif,subtitles="#{File.path(subPath)}" "#{outputPath}"`
end

def embedSubs(video,subPath)
  outputPath = getPaths(video) + '_embedsubs.mp4'
`"#{FfmpegPath}" -i "#{File.path(video)}" -i "#{File.path(subPath)}" -c:v libx264 -pix_fmt yuv420p -c:a aac -crf 25 -movflags +faststart -vf yadif -scodec mov_text -metadata:s:s:0 language=eng "#{outputPath}"`
end

def makePlainText(video,subPath)
  subs = File.readlines(subPath)
  outputPath = getPaths(video)
  plainText = []
  subs.each do |line| 
    if line.match(/([0-9])([0-9]):([0-9])([0-9]):([0-9])([0-9]).([0-9])([0-9])([0-9])/)
      iterator = 1
      until subs[subs.index(line) + iterator].strip.empty?
        plainText << subs[subs.index(line) + iterator]
        iterator += 1
      end
    end
  end
  File.open(outputPath + 'plain.txt', "w+") do |f|
    f.puts(plainText)
  end
end

# Gather inputs 
ARGV.each do |input|
  inputs << input if File.file?(input)
  Dir.glob(input + '/*').each {|file| inputs << file} if File.directory?(input)
end

inputs.each {|target| checkMime(target)}
@vidTargets.each do |video|
  subPath = @subTargets.select {|x| File.basename(x,'.*').include?(File.basename(video,'.*'))}

  if subPath.length > 1
    subPath = @subTargets.select {|x| File.extname(x) == '.vtt' }
  end
  if subPath.length == 0
    puts "No results found for #{video}"
    next
  else
    subPath = subPath[0]
  end
  if options.include?('burn')
    burnSubs(video,subPath)
  end
  if options.include?('embed')
    embedSubs(video,subPath)
  end
  if options.empty?
    embedSubs(video,subPath)
  end
  makePlainText(video,subPath)
end
  
