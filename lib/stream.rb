module FFMPEG
  class Stream
    inline :C do |builder|
      FFMPEG.builder_defaults builder

      ##
      # :singleton-method: from

      builder.c_singleton <<-C
        VALUE from(VALUE _format_context, int index) {
          AVFormatContext *format_context;
          VALUE obj;
          int idx = index;

          Data_Get_Struct(_format_context, AVFormatContext, format_context);

          obj = Data_Wrap_Struct(self, 0, NULL,
                                 format_context->streams[idx]);

          rb_funcall(obj, rb_intern("initialize"), 0);

          return obj;
        }
      C

      ##
      # :method: codec_context

      builder.c <<-C
        VALUE codec_context() {
          VALUE codec_context_klass;

          codec_context_klass = rb_path2class("FFMPEG::CodecContext");

          return rb_funcall(codec_context_klass, rb_intern("from"), 1, self);
        }
      C

      ##
      # :method: context_defaults

      builder.c <<-C
        VALUE context_defaults(int codec_type) {
          AVStream *stream;

          Data_Get_Struct(self, AVStream, stream);

          avcodec_get_context_defaults2(stream->codec, codec_type);

          return self;
        }
      C

      ##
      # :method: r_frame_rate

      builder.c <<-C
        VALUE r_frame_rate() {
          AVStream *stream;
          AVRational *r_frame_rate;

          Data_Get_Struct(self, AVStream, stream);

          r_frame_rate = &(stream->r_frame_rate);

          return ffmpeg_rat2obj(r_frame_rate);
        }
      C

      ##
      # :method: time_base

      builder.c <<-C
        VALUE time_base() {
          AVStream *stream;
          AVRational *time_base;

          Data_Get_Struct(self, AVStream, stream);

          time_base = &(stream->time_base);

          return ffmpeg_rat2obj(time_base);
        }
      C

      builder.struct_name = 'AVStream'
      builder.accessor :id,           'int'
      builder.accessor :last_IP_duration, 'int'
      builder.accessor :nb_index_entries, 'int'
      builder.accessor :stream_index, 'int', :index

      builder.accessor :cur_dts, 'int64_t'
      builder.accessor :duration, 'int64_t'
      builder.accessor :last_IP_pts, 'int64_t'
      builder.accessor :nb_frames, 'int64_t'
      builder.accessor :start_time, 'int64_t'

      builder.accessor :quality, 'double'

    end

    attr_accessor :next_pts
    attr_accessor :pts
    attr_accessor :sync_pts

    def initialize
      @next_pts = FFMPEG::NOPTS_VALUE
      @pts = 0
      @sync_pts = 0
    end

    def inspect
      "#<%s:%x %s>" % [self.class, object_id, codec_context.codec_type]
    end

  end
end