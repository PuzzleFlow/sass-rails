require 'tilt'
require 'sprockets'

module Sass::Rails

  class Resolver

    attr_accessor :context

    def initialize(context)
      @context = context
    end

    def resolve(path, content_type = :self)
      options = {}
      options[:content_type] = content_type unless content_type.nil?
      simulate_sprockets_resolve(path, options)
    rescue Sprockets::FileNotFound, Sprockets::ContentTypeMismatch
      nil
    end

    # Sprockets resolve does not really support absolute paths in 2.x
    # (it requires exact file name, but we want to be smarter)
    # Therefore we simulate that method.
    # (tested with 2.2.2)
    def simulate_sprockets_resolve(path, options = {}, &block)
      pathname   = Pathname.new(path)
      attributes = context.environment.attributes_for(pathname)

      if pathname.absolute? && context.environment.stat(pathname)
        pathname

      elsif content_type = options[:content_type]
        content_type = context.content_type if content_type == :self

        if attributes.format_extension
          if content_type != attributes.content_type
            raise ContentTypeMismatch, "#{path} is " +
              "'#{attributes.content_type}', not '#{content_type}'"
          end
        end

        simulate_sprockets_resolve(path) do |candidate|
          if context.content_type == context.environment.content_type_of(candidate)
            return candidate
          end
        end

        raise Sprockets::FileNotFound, "couldn't find file '#{path}'"
      else
        context.environment.resolve(path, :base_path => self.pathname.dirname, &block)
      end
    end

    def source_path(path, ext)
      context.asset_paths.compute_source_path(path, ::Rails.application.config.assets.prefix, ext)
    end

    def public_path(path, scope = nil, options = {})
      context.asset_paths.compute_public_path(path, ::Rails.application.config.assets.prefix, options)
    end

    def process(path)
      context.environment[path].to_s
    end

    def image_path(img)
      context.image_path(img)
    end

    def video_path(video)
      context.video_path(video)
    end

    def audio_path(audio)
      context.audio_path(audio)
    end

    def javascript_path(javascript)
      context.javascript_path(javascript)
    end

    def stylesheet_path(stylesheet)
      context.stylesheet_path(stylesheet)
    end

    def font_path(font)
      context.font_path(font)
    end
  end

  class SassTemplate < Tilt::SassTemplate
    self.default_mime_type = 'text/css'

    def self.engine_initialized?
      defined?(::Sass::Engine)
    end

    def initialize_engine
      require_template_library 'sass'
    end

    def syntax
      :sass
    end

    def sass_options_from_rails(scope)
      scope.environment.context_class.sass_config
    end

    def sass_options(scope)
      importer = self.importer(scope)
      options = sass_options_from_rails(scope)
      load_paths = (options[:load_paths] || []).dup
      load_paths.unshift(importer)
      resolver = Resolver.new(scope)
      css_filename = resolver.source_path(scope.logical_path, 'css')
      options.merge(
        :filename => eval_file,
        :css_filename => css_filename,
        :line => line,
        :syntax => syntax,
        :importer => importer,
        :load_paths => load_paths,
        :custom => {
          :resolver => resolver
        }
      )
    end

    def importer(scope)
      Sass::Rails::Importer.new(scope)
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      Sass::Engine.new(data, sass_options(scope)).render
    end
  end

  class ScssTemplate < SassTemplate
    self.default_mime_type = 'text/css'

    def syntax
      :scss
    end
  end
end
