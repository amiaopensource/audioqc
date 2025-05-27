def load_options(option_file)
  options = CSV.parse(File.read(option_file))
  $high_volume = options[1][0].to_f
  $stereo_phase_thresh = options[1][1].to_f
  $dual_mono_phase_thresh = options[1][2].to_f
  $conch_policy = options[1][3]
  $output_path_custom = options[1][4]
  $ffmpeg_path = options[1][5]
  $ffprobe_path = options[1][6]
  $mediaconch_path = options[1][7]
  $ffmpeg_path = 'ffmpeg' if ! File.exist?($ffmpeg_path.to_s)
  $ffprobe_path = 'ffprobe' if ! File.exist?($ffprobe_path.to_s)
  $mediaconch_path = 'mediaconch' if ! File.exist?($mediaconch_path.to_s)
end

class QcTarget
  def initialize(value)
    @input_path = value
    @warnings = []
    @hash = ''
  end

  def calculatehash
    @md5 = `#{$ffmpeg_path} -nostdin -i "#{@input_path}" -c copy -f md5 -`.chomp.reverse.chomp('=5DM').reverse.upcase
  end

  def probe
    channel_one_vol = []
    channel_two_vol = []
    overall_volume = []
    @high_volume_count = 0
    ffprobe_command = "#{$ffprobe_path} -print_format json -threads auto -show_entries frame_tags=lavfi.astats.Overall.Number_of_samples,lavfi.astats.Overall.Peak_level,lavfi.astats.Overall.Max_difference,lavfi.astats.1.Peak_level,lavfi.astats.2.Peak_level,lavfi.astats.1.Peak_level,lavfi.astats.Overall.Mean_difference,lavfi.astats.Overall.Peak_level,lavfi.r128.I -f lavfi -i \"amovie='#{@input_path}'" + ',astats=reset=1:metadata=1,ebur128=metadata=1"'
    ffprobe_command.gsub!(':','\:')
    ffprobe_out = JSON.parse(`#{ffprobe_command}`)
    ffprobe_out['frames'].each do |frame|
      if frame['tags']['lavfi.astats.1.Peak_level'] == '-inf' || frame['tags']['lavfi.astats.2.Peak_level'] == '-inf'
        next
      else
        channel_one_vol << frame['tags']['lavfi.astats.1.Peak_level'].to_f.round(2)
        channel_two_vol << frame['tags']['lavfi.astats.2.Peak_level'].to_f.round(2) unless frame['tags']['lavfi.astats.2.Peak_level'].nil?
        overall_volume << frame['tags']['lavfi.astats.Overall.Peak_level'].to_f.round(2)
      end
    end
  @integratedLoudness = ffprobe_out['frames'][ffprobe_out.length - 3]['tags']['lavfi.r128.I']
  @channel_one_max = channel_one_vol.max
  @channel_two_max = channel_two_vol.max
  @overall_volume_max = overall_volume.max
  overall_volume.each {|volume| @high_volume_count += 1 if volume > $high_volume}
  output = [@channel_one_max, @channel_two_max, @overall_volume_max, @integratedLoudness]
  end

  def phase
    phase_values = []
    phase_command = `#{$ffmpeg_path} -i "#{@input_path}" -af aformat=dblp,channelsplit,axcorrelate=size=1024:algo=fast -f wav - | #{$ffprobe_path} -print_format json -threads auto -show_entries frame_tags=lavfi.astats.1.DC_offset -f lavfi -i "amovie='pipe\\:0',astats=reset=1:metadata=1"`
    phase_info = JSON.parse(phase_command)
    phase_info['frames'].each {|frame| phase_values << frame['tags']['lavfi.astats.1.DC_offset'].to_f}
    @average_phase = (phase_values.sum/phase_values.count).round(2)
  end

  def media_conch
    @media_conch_out = CSV.parse(`#{$mediaconch_path} --Policy=#{$conch_policy} --Format=csv "#{@input_path}"`)
    @conch_failures = []
    if @media_conch_out[1][1] != 'pass'
      @conch_result = 'fail'
      @warnings << 'media conch fail'
      @media_conch_out[1].each_with_index do |value, index|
        if value =='fail'
         @conch_failures << @media_conch_out[0][index]
        end
      end
    else 
      @conch_result = 'pass'
    end
  end

  def media_info
    @media_info_out = JSON.parse(`mediainfo --Output=JSON "#{@input_path}"`)
    @channel_count = @media_info_out['media']['track'][1]['Channels']
    @duration_normalized = Time.at(@media_info_out['media']['track'][0]['Duration'].to_f).utc.strftime('%H:%M:%S')
    #check for BEXT coding history metadata
    if (@media_info_out['media']['track'][0]['extra'] != nil)
      if @media_info_out['media']['track'][0]['extra']['bext_Present'] == 'Yes' && @media_info_out['media']['track'][0]['Encoded_Library_Settings']
        @coding_history = @media_info_out['media']['track'][0]['Encoded_Library_Settings']
        @stereo_count = @media_info_out['media']['track'][0]['Encoded_Library_Settings'].scan(/stereo/i).count
        @mono_count = @media_info_out['media']['track'][0]['Encoded_Library_Settings'].scan(/mono/i).count
        @dual_count = @media_info_out['media']['track'][0]['Encoded_Library_Settings'].gsub("dual-sided","").scan(/dual/i).count
        @signal_chain_count = @media_info_out['media']['track'][0]['Encoded_Library_Settings'].scan(/A=/).count
      end
    else
      @warnings << 'No BEXT'
    end
    if @media_info_out['media']['track'][1]['extra']
      @stored_md5 = @media_info_out['media']['track'][1]['extra']['MD5'].chomp
    else
      @stored_md5 = nil
    end
  end

  
  # only used in parallel version
  # def store_hash(hash)
  #   @md5 = hash
  # end

  #only used in parallel version
  # def store_probe(ffprobe_out)
  #   @channel_one_max = ffprobe_out[0]
  #   @channel_two_max = ffprobe_out[1]
  #   @integratedLoudness = ffprobe_out[2]
  # end

  #only used in parallel version
  # def store_phase(average_phase)
  #   @average_phase = average_phase
  # end

  def generate_warnings
    #MD5 Warnings
    if @stored_md5.nil?
      @warnings << 'No Stored MD5'
      @md5_alert = 'No MD5'
    elsif @stored_md5 != @md5
      @warnings << 'Failed MD5 Verification'
      @md5_alert = "Failed: #{@md5}"
    else
      @md5_alert = 'Pass'
    end

    #Average Phase Warnings
    if ! @dual_count.nil? && ! @stereo_count.nil?
      if @dual_count > 0
        phase_limit = $dual_mono_phase_thresh
      elsif @stereo_count > 1
        phase_limit = $stereo_phase_thresh
      else
        phase_limit = $stereo_phase_thresh
      end
    else
      phase_limit = $stereo_phase_thresh
    end
    if @average_phase < phase_limit
      @warnings << 'Phase Warning'
    end

    #Volume Warnings
    if @channel_one_max > $high_volume || @overall_volume_max >  $high_volume
      @warnings << "High Volume"
    elsif ! @channel_two_max.nil? && @channel_two_max > $high_volume
      @warnings << "High Volume"
    end

    # Check Coding History for accuracy vs. channels
    if ! @dual_count.nil? && ! @stereo_count.nil?
      if @channel_count == "1"
        unless (@mono_count - @dual_count) == @signal_chain_count
          @warnings << "BEXT Coding History channels don't match file"
        end
      elsif @channel_count == "2"
        unless @stereo_count + @dual_count == @signal_chain_count
          @warnings << "BEXT Coding History channels don't match file"
        end
      end
    end
    @status = 'pass'
  end

  def make_jpg(output_jpg_dir)
    Dir.mkdir(output_jpg_dir) unless File.exist?(output_jpg_dir)
    output_path = output_jpg_dir + '/' + File.basename(@input_path,File.extname(@input_path)) + '.jpg'
    `ffmpeg -i #{@input_path} -f lavfi -i color=c=#c0c0c0:s=938x240 -filter_complex " \
    [0:a]asplit=3[a][b][c],[a]showwavespic=s=938x240:split_channels=1:colors=#3232c8:filter=peak[pk], \
    [b]showwavespic=s=938x240:split_channels=1:colors=#6464dc[rms], \
    [c]showspectrumpic=s=640x240[spectrum], \
    [pk][rms]overlay=format=auto[nobg], \
    [1:v][nobg]overlay=format=auto[bg], \
    [bg][spectrum]vstack=inputs=2,drawtext=fontsize=20:fontcolor=black:text="#{File.basename(@input_path)}"[out0]" \
    -map [out0] -frames:v 1 -update true #{output_path}`
  end

  def error_warning
    @status = 'fail'
  end

  def csv_line
    return "@warnings,@input_path,@channel_one_max,@channel_two_max,@average_phase,@md5"
  end

  def write_csv_line(output_csv)
    if ! File.exist?(output_csv)
      header = ['Path', 'Warnings', 'Channels', 'Duration', 'Volume max', 'Channel 1 max', 'Channel 2 max', 'Number of High Volume Frames', 'Average Phase', 'Integrated Loudness', 'MD5 check', 'Mediaconch Status', 'Mediaconch Failures', 'Coding History']
      CSV.open(output_csv, 'a') do |csv|
        csv << header
      end
    end
    if @status == 'fail'
      line = [@input_path, 'Failed to Scan']
    elsif @status == 'pass'
      line = [@input_path,@warnings.flatten.join(', '),@channel_count, @duration_normalized, @overall_volume_max, @channel_one_max,@channel_two_max,@high_volume_count,@average_phase,@integratedLoudness,@md5_alert, @conch_result, @conch_failures.flatten.join(', '),@coding_history]
    end
    CSV.open(output_csv, 'a') do |csv|
      csv << line
    end
  end
end