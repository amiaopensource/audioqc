#!/usr/bin/env ruby

require 'flammarion'
require 'yaml'
require 'mediainfo'
require 'optparse'
require 'pry'

InputItemNumbers = []
HuskyLinks = ['https://web.archive.org/web/20090820093233/http://geocities.com/aleharobed/siberian_husky_run_mini.gif',
'https://web.archive.org/web/20090829072442/http://www.geocities.com/sakiaakennelz/walkingsiberianhusky.gif',
'https://web.archive.org/web/20091019155615/http://de.geocities.com/Mausezwerg1981/huskyspringend.gif']

ARGV.options do |opts|
  opts.on("-i", "--item-number=val", String)  { |val| InputItemNumbers << val }
  opts.parse!
end

# Check for $windows
if Gem.win_platform?
  $windows = true
else
  $windows = false
end

#Set up/Load config
scriptPath = __dir__
configPath = scriptPath + "/uw-metaedit-config.txt"
unless File.exist?(configPath)
  configBlank = {
    "originator" =>'',
    "history1" => '',
    "history2" => '',
    "collection" => ''
  }
  File.open(configPath, "w") { |file| file.write(configBlank.to_yaml) }
end

 configOptions = YAML.load(File.read(configPath))

def getOutputDir()
  if $windows
    targetFile = `powershell "Add-Type -AssemblyName System.$windows.forms|Out-Null;$f=New-Object System.$windows.Forms.FolderBrowserDialog;$f.SelectedPath = 'C:\';$f.Description = 'Select Output Directory';$f.ShowDialog((New-Object System.$windows.Forms.Form -Property @{TopMost = $true }))|Out-Null;$f.SelectedPath"`.strip + '\\'
  else
    targetFile = `zenity --file-selection`.strip
  end
  return targetFile
end


def embedBext(targetFile, origin, codeHist1, codeHist2, collNumber, itemNumber)
  command = []
  moddatetime = File.mtime(targetFile)
  moddate = moddatetime.strftime("%Y-%m-%d")
  modtime = moddatetime.strftime("%H:%M:%S")
  history = codeHist1 + "\n" + codeHist2
  unless itemNumber.nil?
    description = "Collection number: #{collNumber}, " + "Item Number: #{itemNumber}, " + "Original File Name #{File.basename('/home/weaver/Desktop/test.wav',".*")}"
  else
    description = "Collection number: #{collNumber}, " + "Item Number: #{itemNumber}, " + "Original File Name #{File.basename('/home/weaver/Desktop/test.wav',".*")}"
  end
  command << 'bwfmetaedit' 
  command << '--reject-overwrite'
  command << "--Originator=#{origin}"
  command << "--Description=Collection number: #{collNumber}, Item number: #{itemNumber}"
  command << "--OriginatorReference=#{File.basename(targetFile)}"
  command << "--History=#{history}"
  command << "--IARL=#{origin}"
  command << "--OriginationDate=#{moddate}"
  command << "--OriginationTime=#{modtime}"
  command << '--MD5-Embed'
  command << "#{targetFile}"
  if system(*command) && Gui
    $window.alert("Embedding done")
  elsif Gui
    $window.alert("Error occurred - please double check file and settings")
  end
end


# Set up config variables
originator = configOptions['originator']
history1 = configOptions['history1']
history2 = configOptions['history2']
collection = configOptions['collection']

unless ARGV.length.positive?
  Gui = true
  $window = Flammarion::Engraving.new
  $window.image(HuskyLinks.sample)
  $window.title("Welcome to UW Metaedit 2.0")
  $window.pane("Items").orientation = :horizontal
  $window.pane("Items").puts("Item Info", replace:true)
  collNumber = $window.pane("Items").input('Collection Number(s)', options = {value:collection})
  itemNumber = $window.pane("Items").input('Item Number')
  $window.pane("BEXT").puts("BEXT Info", replace:true)
  origin = $window.pane("BEXT").input('Originator', options = {value:originator})
  codeHist1 = $window.pane("BEXT").input('Encoding History Line 1' , options = {value:history1})
  codeHist2 = $window.pane("BEXT").input('Encoding History Line 2', options = {value:history2})
    $window.pane("Controls").button("Save Settings") {
    configOptions['originator'] = origin.to_s
    configOptions['history1'] = codeHist1.to_s
    configOptions['history2'] = codeHist2.to_s
    configOptions['collection'] = collNumber.to_s
    File.open(configPath, "w") { |file| file.write(configOptions.to_yaml) }
   }
  $window.pane("Controls").orientation = :horizontal
  targetFile = $window.pane("Controls").button('Select Target') { targetFile = getOutputDir() }
  $window.pane("Controls").button('Embed Metadata') { embedBext(targetFile, origin, codeHist1, codeHist2, collNumber, itemNumber) }
  $window.wait_until_closed
else
  Gui = false
  if ARGV.length != InputItemNumbers.length && InputItemNumbers.length != 0
    puts "Number of inputs does not match number of item numbers - please recheck your command."
    exit
  end
  ARGV.each do |targetFile|
    itemNumber = InputItemNumbers[ARGV.index(targetFile)]
    if File.exist?(targetFile)
      embedBext(targetFile, originator, history1, history2, collection, itemNumber)
    else
      puts "File not found: Skipping #{targetFile}"
    end
  end
end