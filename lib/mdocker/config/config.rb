require 'yaml'

module MDocker
  class Config

    attr_reader :data

    def initialize(sources = [])
      sources = [sources] unless Array === sources
      @data = load_config sources
    end

    def get(key, default_value=nil, stack=[])
      return nil if key.nil?
      raise StandardError.new "self referencing loop detected for '#{key}'" if stack.include? key
      interpolate(find_value(key.split('.'), @data), stack + [key]) || default_value
    end

    def +(config)
      config = Config.new(config) unless Config === config
      Config.new([@data, config.data])
    end

    def ==(config)
      @data == config.data
    end

    def merge(first_key, second_key)
      first_value = get(first_key, {})
      second_value = get(second_key, {})
      unless Hash === first_value && Hash === second_value
        raise StandardError.new "values of '#{first_key}' and '#{second_key}' properties expected to be of type Hash"
      end
      MDocker::Util::deep_merge(first_value, second_value)
    end

    def to_s
      YAML::dump @data
    end

    private

    def load_config(configs_or_paths)
      configs_or_paths.inject({}) do |config, data|
        begin
          hash = Hash === data ? data : YAML::load_file(data)
          MDocker::Util::deep_merge(config, hash)
        rescue
          config
        end
      end
    end

    def interpolate(value, stack)
      case value
      when Array
        value.map { |item| interpolate(item, stack) }
      when Hash
        value.map { |k,v| [k, interpolate(v, stack)] }.to_h
      when String
        key = value[/^%{([^%{}]+)}$/, 1]
        if key
          get(key, value, stack)
        else
          new_value = value.scan(/%{[^%{}]+}/).uniq.inject(value) do |str, k|
            str.gsub(k, interpolate(k, stack).to_s)
          end
          new_value == value ? new_value : interpolate(new_value, stack)
        end
      else
        value
      end
    end

    def find_value(key_segments, hash)
      if key_segments.empty?
        hash
      elsif hash.nil?
        nil
      elsif Array === hash
        begin
          find_value(key_segments.drop(1), hash[Integer(key_segments[0])])
        rescue
          nil
        end
      else
        keys = key_segments.inject([[]]) { |array, segment| array << (array.last + [segment]) }
        keys = keys.drop(1).reverse
        keys.detect do |key|
          value = find_value(key_segments.drop(key.length), hash[key.join('.')])
          break value if value
        end
      end
    end

  end
end