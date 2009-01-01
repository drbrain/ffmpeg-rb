module FFMPEG
  class FormatContext
    
    DTS_DELTA_THRESHOLD = 10
    
    attr_accessor :sync_pts
    
    inline :C do |builder|
      FFMPEG.builder_defaults builder
      
      # free methods
      # 
      # format context is responsible for freeing its codecs, codec_context and streams.
      # Ruby corresponding objects must hold a reference (instance variable) to
      # their parent object so format context do not free memory before ruby object are
      # garbage collected.
      builder.prefix <<-C
        
        static void free_codecs(AVFormatContext * format_context)
        {
          int i;
          for(i = 0; i < format_context->nb_streams; i++) {
            if (format_context->streams[i]->codec->codec)
              avcodec_close(format_context->streams[i]->codec);
          }
        }
        
        static void free_streams(AVFormatContext * format_context)
        {
          int i;
          for(i = 0; i < format_context->nb_streams; i++) {
            av_free(format_context->streams[i]->codec);
            av_free(format_context->streams[i]);
          }
        }
        
        static void free_format_context(AVFormatContext *format_context) {
          if (format_context) {
            
            free_codecs(format_context);
            
            if (format_context->iformat) {
              av_close_input_file(format_context);
            } else {
              free_streams(format_context);
              av_free(format_context);
            }
          }
        }
      C
      
      ##
      # :singleton-method: allocate
      
      builder.c_singleton <<-C
        VALUE allocate() {
          AVFormatContext *format_context;
          
          format_context = av_alloc_format_context();
          
          VALUE obj = Data_Wrap_Struct(self, 0, free_format_context, format_context);
          
          return obj;
        }
      C
      
      ##
      # :method: input_format
      
      builder.c <<-C
        VALUE input_format() {
          VALUE format_klass;
          
          format_klass = rb_path2class("FFMPEG::InputFormat");
          
          return rb_funcall(format_klass, rb_intern("from"), 1, self);
        }
      C
      
      ##
      # :method: open
      
      builder.c <<-C, :method_name => :open
        VALUE oc_open(char *file_name, int flags) {
          AVFormatContext *format_context;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          
          if (url_fopen(&format_context->pb, file_name, flags) < 0) {
            rb_raise(rb_eRuntimeError, "could not open %s", file_name);
          }
          
          return self;
        }
      C
      
      ##
      # :method: open_input_file
      
      builder.c <<-C
        VALUE open_input_file(char *filename, VALUE _input_format, int buf_size,
                              VALUE _format_parameters) {
          AVFormatContext *format_context;
          AVInputFormat *input_format = NULL;
          AVFormatParameters *format_parameters = NULL;
          int ret;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          
          if (RTEST(_input_format)) {
            Data_Get_Struct(_input_format, AVInputFormat, input_format);
          }
          
          if (RTEST(_format_parameters)) {
            Data_Get_Struct(_format_parameters, AVFormatParameters,
                            format_parameters);
          }
          
          ret = av_open_input_file(&format_context, filename, input_format,
                                   buf_size, format_parameters);
          
          if (ret != 0) {
            rb_raise(rb_eArgError, "error opening file (av_open_input_file)");
          }
          
          DATA_PTR(self) = format_context;
          
          return self;
        }
      C
      
      ##
      # :method: output_format
      
      builder.c <<-C
        VALUE output_format() {
          VALUE format_klass;
          
          format_klass = rb_path2class("FFMPEG::OutputFormat");
          
          return rb_funcall(format_klass, rb_intern("from"), 1, self);
        }
      C
      
      ##
      # :method: set_parameters
      
      builder.c <<-C
        VALUE set_parameters(VALUE _params) {
          AVFormatParameters *format_parameters;
          AVFormatContext *format_context;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          Data_Get_Struct(_params, AVFormatParameters, format_parameters);
          
          if (av_set_parameters(format_context, format_parameters) < 0) {
            rb_raise(rb_eRuntimeError, "invalid encoding parameters");
          }
          
          return self;
        }
      C
      
      ##
      # :method: stream_info
      
      builder.c <<-C
        VALUE stream_info() {
          AVFormatContext *format_context;
          
          if (RTEST(rb_iv_get(self, "@stream_info")))
             return Qtrue;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          
          if (av_find_stream_info(format_context) < 0)
            return Qfalse;
          
          rb_iv_set(self, "@stream_info", Qtrue);
          
          return Qtrue;
         }
      C
      
      ##
      # :method: interleaved_write
      
      builder.c <<-C
        VALUE interleaved_write(VALUE _packet) {
          AVFormatContext *format_context;
          AVPacket *packet;
          int ret;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          Data_Get_Struct(_packet, AVPacket, packet);
          
          ret = av_interleaved_write_frame(format_context, packet);
          
          if (ret < 0) {
            rb_raise(rb_eRuntimeError, "av_interleaved_write_frame failed");
          }
          
          return INT2NUM(ret);
        }
      C
      
      ##
      # :method: new_output_stream
      
      builder.c <<-C
        VALUE new_output_stream() {
          AVFormatContext *format_context;
          AVStream *stream;
          VALUE stream_klass, obj;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          
          stream = av_new_stream(format_context, format_context->nb_streams);
          
          if (!stream) {
            rb_raise(rb_eNoMemError, "could not allocate stream");
          }
          
          stream_klass = rb_path2class("FFMPEG::Stream");
          
          obj = Data_Wrap_Struct(stream_klass, NULL, NULL, stream);
          
          rb_iv_set(obj, "@stream_info", Qtrue);
          rb_funcall(obj, rb_intern("initialize"), 1, self);
          
          return obj;
        }
      C
      
      ##
      # :method: oformat=
      
      builder.c <<-C
        VALUE oformat_equals(VALUE _output_format) {
          AVFormatContext *format_context;
          AVOutputFormat *output_format;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          Data_Get_Struct(_output_format, AVOutputFormat, output_format);
          
          format_context->oformat = output_format;
          
          return self;
        }
      C
      
      ##
      # :method: read_frame
      
      builder.c <<-C
        VALUE read_frame(VALUE rb_packet) {
          AVFormatContext *format_context;
          AVPacket *packet;
          int err;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          Data_Get_Struct(rb_packet, AVPacket, packet);
          
          err = av_read_frame(format_context, packet);
          
          if (err < 0)
            return Qfalse;
          
          // refresh the buffer
          rb_funcall(rb_packet, rb_intern("buffer"), 0);
          
          return Qtrue;
        }
      C
      
      ##
      # :method: streams
      
      builder.c <<-C
        VALUE streams() {
          int i;
          VALUE streams, stream, stream_klass;
          AVFormatContext *format_context;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          
          if (!RTEST(rb_iv_get(self, "@stream_info"))) {
            if (!RTEST(stream_info(self))) {
              return Qnil; /* HACK raise exception */
            }
          }
          
          streams = rb_ary_new();
          
          stream_klass = rb_path2class("FFMPEG::Stream");
          
          for (i = 0; i < format_context->nb_streams; i++) {
            stream = rb_funcall(stream_klass, rb_intern("from"), 2, self,
                                INT2NUM(i));
            rb_ary_push(streams, stream);
          }
          
          return streams;
        }
      C
      
      ##
      # :method: write_header
      
      builder.c <<-C
        VALUE write_header() {
          AVFormatContext *format_context;
          
          Data_Get_Struct(self, AVFormatContext, format_context);
          
          if (av_write_header(format_context) < 0) {
            rb_raise(rb_eRuntimeError, "could not write header for output file");
          }
          
          return self;
        }
      C
      
      ##
      # :method: write_trailer
      
      builder.c %q|
        VALUE write_trailer() {
          AVStream *stream;
          Data_Get_Struct(self, AVStream, stream);
          av_write_trailer(stream);
          
          return self;
        }
      |
      
      builder.struct_name = 'AVFormatContext'
      builder.reader :album,     'char *'
      builder.reader :author,    'char *'
      builder.reader :comment,   'char *'
      builder.reader :copyright, 'char *'
      builder.reader :filename,  'char *'
      builder.reader :genre,     'char *'
      builder.reader :title,     'char *'
      
      builder.accessor :loop_output, 'int'
      builder.accessor :max_delay,   'int'
      builder.accessor :preload,     'int'
      
      builder.accessor :bit_rate,    'int'
      builder.reader :track,       'int'
      builder.reader :year,        'int'
      
      builder.reader :duration,   'int64_t'
      builder.reader :file_size,  'int64_t'
      builder.reader :start_time, 'int64_t'
      builder.reader :timestamp,  'int64_t'
    end
    
    # file accepts a file or a IO object for output
    #
    # IO on output will make the output not seekable
    def initialize(file, output = false)
      @input = !output
      @timestamp_offset = 0
      @sync_pts = 0
      @video_stream = nil
      @stream_info = nil
      unless output then
        raise NotImplementedError, "input from IO not supported" unless
          String === file
        
        open_input_file file, nil, 0, nil
        
        stream_info
      else
        @stream_info = true
        
        output_format = FFMPEG::OutputFormat.guess_format nil, file, nil
        
        self.oformat = output_format
        #self.filename = file # HACK av_strlcpy
        
        file = "pipe:#{file.fileno}" if IO === file
        
        open file, FFMPEG::URL_WRONLY
      end
    end
    
    def inspect
      "#<%s:0x%x @input=%p @stream_info=%p @sync_pts=%d>" % [
        self.class, object_id,
        @input, @stream_info, @sync_pts
      ]
    end
    
    def encode_frame(frame, output_stream)
      @output_buffer ||= FrameBuffer.new(1048576)
      @output_packet ||= FFMPEG::Packet.new
      packet = @output_packet.clean
      
      packet.stream_index = output_stream.stream_index
      
      video_encoder = output_stream.codec_context
      frame.pts = output_stream.sync_pts
      
      bytes = video_encoder.encode_video frame, @output_buffer
      
      #p :encoded => bytes
      
      packet.buffer = @output_buffer
      packet.size = bytes
      
      if video_encoder.coded_frame and
        video_encoder.coded_frame.pts != FFMPEG::NOPTS_VALUE then
        packet.pts = FFMPEG::Rational.rescale_q video_encoder.coded_frame.pts,
                                                video_encoder.time_base,
                                                output_stream.time_base
      else
        packet.pts = output_stream.sync_pts
      end
      
      # puts video_encoder.coded_frame.pict_type
      
      if video_encoder.coded_frame and
          video_encoder.coded_frame.key_frame then
        packet.flags |= FFMPEG::Packet::FLAG_KEY
      end
      
      #puts video_encoder.coded_frame.type.to_s
      STDOUT.print "\rtime: #{format "%7.2f", output_stream.sync_pts * video_encoder.time_base.to_f} #{format "%10d", packet.pts} #{video_encoder.coded_frame.type}"
      STDOUT.flush
      packet
    end
    
    def output(packet, output_context, output_stream, input_stream)
      video_decoder = input_stream.codec_context
      @in_frame ||= FFMPEG::Frame.new(video_decoder.width, video_decoder.height, video_decoder.pix_fmt)
      
      input_stream.next_pts = input_stream.pts if input_stream.next_pts == NOPTS_VALUE
      
      if packet.dts != FFMPEG::NOPTS_VALUE then
        input_stream.pts = FFMPEG::Rational.rescale_q packet.dts,
          input_stream.time_base, FFMPEG::TIME_BASE_Q
        input_stream.next_pts = input_stream.pts
      end
      
      len = packet.size
      
      while len > 0 or
            (packet.nil? and
             input_stream.next_pts != input_stream.pts)
             
        input_stream.pts = input_stream.next_pts
        
        data_size = video_decoder.width * video_decoder.height * 3 / 2
        
        @in_frame.defaults
        @in_frame.quality = input_stream.quality
        
        got_picture, bytes = video_decoder.decode_video @in_frame,
         packet.buffer
        
        break :fail if bytes.nil?
        
        @in_frame = nil unless got_picture
        
        if video_decoder.time_base.num != 0 then
          input_stream.next_pts += FFMPEG::TIME_BASE *
                                  video_decoder.time_base.num /
                                  video_decoder.time_base.den
        end
        
        len = 0
        
        @scaler ||= FFMPEG::ImageScaler.new video_decoder.width,
                                      video_decoder.height,
                                      video_decoder.pix_fmt,
                                      output_stream.codec_context.width,
                                      output_stream.codec_context.height,
                                      output_stream.codec_context.pix_fmt,
                                      FFMPEG::ImageScaler::BICUBIC
        
        output_stream.sync_pts = input_stream.pts / TIME_BASE.to_f / output_stream.codec_context.time_base.to_f
                                                
        output_packet = output_context.encode_frame @scaler.scale(@in_frame), output_stream
        
        # STDERR.puts "Output ts: output_packet.pts:#{output_packet.pts}, output_packet.dts:#{output_packet.dts}"
         
        if output_packet.size > 0 then
          output_context.interleaved_write output_packet
        end
        
        output_context.sync_pts += 1
      end
    end
    
    def transcode_map(&block)
      stream_map = StreamMap.new(self)
      yield stream_map
      raise RuntimeError.new("map is empty !") if stream_map.empty?
      
      prepare_transcoding(stream_map)
      
      # TODO do prep and transcode
      stream_map.output_format_contexts.each do |output_context|
        output_context.write_header
      end
      
      input_packet = FFMPEG::Packet.new
      
      eof = false
      packet_dts = 0
      
      loop do
        input_packet.clean
        
        eof = true unless read_frame input_packet
        
        # next unless input_packet.stream_index == video_stream.stream_index
        
        if input_packet.dts != FFMPEG::NOPTS_VALUE then
          input_packet.dts += FFMPEG::Rational.rescale_q @timestamp_offset,
                                                         FFMPEG::TIME_BASE_Q,
                                                         video_stream.time_base
        end
        
        if input_packet.pts != FFMPEG::NOPTS_VALUE then
          input_packet.pts += FFMPEG::Rational.rescale_q @timestamp_offset,
                                                         FFMPEG::TIME_BASE_Q,
                                                         video_stream.time_base
        end
        
        break :fail if input_packet.pts == NOPTS_VALUE
        # STDERR.puts "input_packet.pts: #{input_packet.pts}, input_packet.dts: #{input_packet.dts}, output_context.sync_pts: #{output_context.sync_pts}"
        stream_map.map[input_packet.stream_index].each do |output_stream|
          output input_packet, output_stream.format_context, output_stream,
            streams[input_packet.stream_index]
        end
      end
      
      output_context.write_trailer
    end
    
    def prepare_transcoding(stream_map)
      stream_map.map.each_pair do |index, output_streams|
        # prepare input stream
        input_stream = streams[index]
        decoder = input_stream.codec_context
        
        video_stream.pts = 0
        video_stream.next_pts = FFMPEG::NOPTS_VALUE
        
        decoder.open Codec.for_decoder(decoder.codec_id)
        
        # prepare output streams
        output_streams.each do |output_stream|
          output_context = output_stream.format_context
          encoder = output_stream.codec_context
          
          output_context.preload = 0.5 * FFMPEG::TIME_BASE
          output_context.max_delay = 0.7 * FFMPEG::TIME_BASE
          output_context.loop_output = FFMPEG::OutputFormat::NO_OUTPUT_LOOP
          
          output_stream.sync_pts = 0
          
          ouput_stream.duration = Rational.rescale_q(video_stream.duration,
            video_stream.time_base, output_video_stream.time_base) if 
              output_stream.duration.zero?
          
          # encoder.open Codec.for_encoder(encoder.codec_id)
          
          if encoder.codec_type == :VIDEO
            
            # TODO preserve ratio if width or height provided
            if encoder.width == 0
              encoder.width = decoder.width
              encoder.height = decoder.heigth
            end
            
            encoder.sample_aspect_ratio.num = 4/3 * encoder.width / encoder.heigth
            encoder.sample_aspect_ratio.den = 255
            
            encoder.bit_rate_tolerance = 0.2 * encoder.bit_rate if
              encoder.bit_rate_tolerance.zero?
            
            encoder.pix_fmt = decoder.pix_fmt if video_encoder.pix_fmt == -1
            
            unless encoder.rc_initial_buffer_occupancy > 1 then
              encoder.rc_initial_buffer_occupancy =
                encoder.rc_buffer_size * 3 / 4
            end
            
          end
          
        end
      end
    end
    
    # output only
    def new_output_video_stream(codec_name=nil, options={})
      stream = new_output_stream
      stream.context_defaults FFMPEG::Codec::VIDEO
      
      codec_id = output_format.guess_codec codec_name, nil, filename, FFMPEG::Codec::VIDEO
      raise "Unable to get a codec : #{codec_name}" unless codec_id
      codec = Codec.for_encoder(codec_id)
      
      encoder = stream.codec_context
      encoder.defaults
      
      (options.keys & [:bit_rate, :width, :height]).each do |key|
        method = "#{key}=".to_sym
        value = options.delete(key)
        raise "required options #{key} not set" if value.nil?
        stream.send(method, value) if stream.respond_to?(method)
        encoder.send(method, value) if encoder.respond_to?(method)
      end
      
      encoder.pix_fmt = options.delete(:pixel_format) || codec.pix_fmts[0]
      encoder.fps = options.delete(:fps) || Rational.new(25,1)
      encoder.bit_rate_tolerance = options.delete(:bit_rate_tolerance) || encoder.bit_rate * 10 / 100
      
      encoder.codec_id = codec_id
      encoder.open(codec)
      
      options.keys.each do |key|
        method = "#{key}=".to_sym
        stream.send(method, options[key]) if stream.respond_to?(method)
        encoder.send(method, options[key]) if encoder.respond_to?(method)
      end
      
      stream
    end
    
    def transcode(wrapper, video, audio, io)
      @scaler = nil
      @in_frame = nil
      output_audio_codec = FFMPEG::Codec.for_encoder audio
      
      output_context = FFMPEG::FormatContext.new io, wrapper
      output_format = output_context.output_format
      
      if video? then
        video_decoder = video_stream.codec_context
        input_video_codec = video_decoder.decoder
        
        output_video_stream = output_context.new_output_stream
        output_video_stream.context_defaults FFMPEG::Codec::VIDEO
        output_video_stream.time_base.num = 1
        output_video_stream.time_base.den = 25
        output_video_stream.duration = Rational.rescale_q(video_stream.duration,
          video_stream.time_base, output_video_stream.time_base)
        
        video_encoder = output_video_stream.codec_context
        video_encoder.defaults
        
        output_video_codec = FFMPEG::Codec.for_encoder video
        
        codec_id = output_format.guess_codec nil, output_context.filename, nil,
                                             FFMPEG::Codec::VIDEO
        video_encoder.time_base.num = 1
        video_encoder.time_base.den = 25
        
        video_encoder.gop_size = 12
        
        video_encoder.width = 300
        video_encoder.height = 200
        
        video_encoder.sample_aspect_ratio.num = 4/3 * 200/300
        video_encoder.sample_aspect_ratio.den = 255
        
        video_encoder.bit_rate =  1000 * 1000
        output_context.bit_rate = 1000 * 1000
        video_encoder.bit_rate_tolerance = 200 * 1000
        video_encoder.max_b_frames = 8
        
        video_encoder.pix_fmt = video_stream.codec_context.pix_fmt
        
        unless video_encoder.rc_initial_buffer_occupancy > 1 then
          video_encoder.rc_initial_buffer_occupancy =
            video_encoder.rc_buffer_size * 3 / 4
        end
      end
      
      #output_context.new_audio_stream if audio?
      
      # HACK needs to use av_strlcpy
      #output_context.album     = album     if album
      #output_context.author    = author    if author
      #output_context.comment   = comment   if comment
      #output_context.copyright = copyright if copyright
      #output_context.genre     = genre     if genre
      #output_context.title     = title     if title
      
      output_context.preload = 0.5 * FFMPEG::TIME_BASE
      output_context.max_delay = 0.7 * FFMPEG::TIME_BASE
      output_context.loop_output = FFMPEG::OutputFormat::NO_OUTPUT_LOOP
      
      bit_buffer_size = video_encoder.width * video_encoder.height * 4
      
      video_encoder.open output_video_codec
      video_decoder.open input_video_codec
      
      video_stream.pts = 0
      video_stream.next_pts = FFMPEG::NOPTS_VALUE
      
      output_context.write_header
      
      input_packet = FFMPEG::Packet.new
      
      output_context.video_stream.sync_pts = 0
      #sync_pts = 0
      eof = false
      packet_dts = 0
      
      loop do
        input_packet.clean
        
        input_pts_min  = 1e100
        output_pts_min = 1e100
        
        output_pts = output_context.video_stream.sync_pts * video_encoder.time_base.to_f
        input_pts  = video_stream.pts.to_f
        
        unless eof then
          input_pts_min  = input_pts  if input_pts  < input_pts_min
          output_pts_min = output_pts if output_pts < output_pts_min
        end
        
        eof = true unless read_frame input_packet
        
        next unless input_packet.stream_index == video_stream.stream_index
        
        if input_packet.dts != FFMPEG::NOPTS_VALUE then
          input_packet.dts += FFMPEG::Rational.rescale_q @timestamp_offset,
                                                         FFMPEG::TIME_BASE_Q,
                                                         video_stream.time_base
        end
        
        if input_packet.pts != FFMPEG::NOPTS_VALUE then
          input_packet.pts += FFMPEG::Rational.rescale_q @timestamp_offset,
                                                         FFMPEG::TIME_BASE_Q,
                                                         video_stream.time_base
        end
        
        # if input_packet.dts != FFMPEG::NOPTS_VALUE and
        #    video_stream.next_pts != FFMPEG::NOPTS_VALUE then
        #   packet_dts = FFMPEG::Rational.rescale_q input_packet.dts,
        #                                           video_stream.time_base,
        #                                           FFMPEG::TIME_BASE_Q
        # 
        #   delta = packet_dts - video_stream.next_pts
        # 
        #   if delta.abs > DTS_DELTA_THRESHOLD * FFMPEG::TIME_BASE or
        #      packet_dts + 1 < video_stream.pts then # HACK && !copy_ts
        #     @timestamp_offset -= delta
        # 
        #     input_packet.dts -= FFMPEG::Rational.rescale_q delta,
        #                                                    FFMPEG::TIME_BASE_Q,
        #                                                    video_stream.time_base
        # 
        #     if input_packet.pts != FFMPEG::NOPTS_VALUE then
        #       input_packet.pts -= FFMPEG::Rational.rescale_q delta,
        #                                                      FFMPEG::TIME_BASE_Q,
        #                                                      video_stream.time_base
        #     end
        #   end
        # end
        
        break :fail if input_packet.pts == NOPTS_VALUE
        # STDERR.puts "input_packet.pts: #{input_packet.pts}, input_packet.dts: #{input_packet.dts}, output_context.sync_pts: #{output_context.sync_pts}"
        output input_packet, output_context, output_context.video_stream, video_stream
      end
      
      output_context.write_trailer
    end
    
    def video?
      !!video_stream
    end
    
    def video_stream
      @video_stream ||= streams.find do |stream|
        stream.codec_context.codec_type == :VIDEO
      end
    end
    
    def write_packet(packet)
      interleaved_write packet
    end
    
  end
end