module FFMPEG
  class FormatParameters
    inline :C do |builder|
      FFMPEG.builder_defaults builder
      builder.prefix <<-C
        void free_format_parameters(AVFormatParameters* format_parameters)
        {
          av_free(format_parameters);
        }
      
      C
      ##
      # :singleton-method: allocate

      builder.c_singleton <<-C
        VALUE allocate() {
          AVFormatParameters *format_parameters;
          VALUE obj;

          format_parameters = av_malloc(sizeof(AVFormatParameters));

          if (!format_parameters)
            rb_raise(rb_eNoMemError, "unable to allocate AVFormatParameters");

          obj = Data_Wrap_Struct(self, free_format_parameters, NULL, format_parameters);

          return obj;
        }
      C

    end
  end
end