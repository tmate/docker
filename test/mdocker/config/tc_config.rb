require_relative '../../test_helper'

module MDocker
  class ConfigTest < Test::Unit::TestCase

    include MDocker::TestBase

    def test_symbolize_keys
      expected = {
          array: [{a: 'a'}, {b: 'b'}]
      }
      input = {
          :array.to_s => [{:a.to_s => 'a'}, {:b.to_s => 'b'}]
      }
      assert_equal expected, MDocker::Util::symbolize_keys(input, true)
    end

    def test_deep_merge_nil_override
      expected = {
          a: 'b',
          c: nil,
          d: 'default_d'
      }
      input1 = {
          a: 'default_a',
          c: 'default_c',
          d: 'default_d'
      }
      input2 = {
          a: 'b',
          c: nil
      }
      assert_equal expected, MDocker::Util::deep_merge(input1, input2)
      assert_true MDocker::Util::deep_merge(input1, input2).has_key?(:c)
    end

    def test_user_value_override
      with_config('config') do |config|
        assert_equal 'user', config.get('value')
        assert_equal 'user', config.get('section/value')
        assert_equal 'project', config.get('section/subsection/subvalue')
      end
    end

    def test_hash_merge
      with_config('config') do |config|
        assert_equal 'user', config.get(:section, :user_only)
        assert_equal 'project', config.get('section/project_only')
        assert_equal 'project_global', config.get('section/project_global_only')
        assert_equal 'global', config.get('section/global_only')
      end
    end

    def test_keys_with_dots
      with_config('config') do |config|
        assert_equal 'value', config.get('section/subsection.dot')
        assert_equal 'value', config.get('section/array.99')
      end
    end


    def test_missing_config
      config_paths = DEFAULT_CONFIG_PATHS.clone
      config_paths.push 'file.yml'

      with_config('config', config_paths) do |config|
        assert_equal 'user', config.get('value')
        assert_equal 'user', config.get('section/value')
      end
    end

    def test_array_value
      with_config('config') do |config|
        assert_true Array === config.get('section/array')
        assert_true Hash === config.get('section/array/3')
        assert_equal 'a', config.get('section/array/1')
        assert_equal 'x', config.get('section/array/3/c')
        assert_equal 'a', config.get(:section, :array, :'1')
      end
    end

    def test_array_oob
      with_config('config') do |config|
        assert_nil config.get('section/array/5')
        assert_equal 'test', config.get(:section, :array, :'5', default:'test')
      end
    end

    def test_array_wrong_index
      with_config('config') do |config|
        assert_nil config.get('section/array/xxx')
        assert_nil config.get('section/array/-100')
      end
    end

    def test_interpolated_string
      with_config('config') do |config|
        assert_equal '%{missing}', config.get('section/interpolated_missing')
        assert_equal 'user', config.get('section/interpolated_value')
        assert_equal 'user user user', config.get('section/interpolated_values')
        assert_equal 'user user user', config.get('section/interpolated_nested_values')
        assert_equal 'user %{missing} user', config.get('section/interpolated_partial')
        assert_equal '%{missing} user %{missing} user', config.get('section/interpolated_partial2')
      end

    end

    # noinspection RubyStringKeysInHashInspection
    def test_interpolated_objects
      with_config('config') do |config|
        assert_equal ({value: 'user'}), config.get('section/interpolated_hash')
        assert_equal ({value: 'user'}), config.get('section/interpolated_hash_value')

        assert_equal %w(user user user), config.get('section/interpolated_array')
        assert_equal %w(user user user), config.get('section/interpolated_array_value')

        assert_equal "[#{%w(user user user).to_s}]", config.get('section/interpolated_array_inline')
        assert_equal "{#{{value: 'user'}.to_s}}", config.get('section/interpolated_hash_inline')
      end
    end

    def test_interpolation_loop
      with_config('config') do |config|
        assert_raise(StandardError) { config.get('loop/self.ref') }
        assert_raise(StandardError) { config.get('loop/longer.self.ref') }
        assert_raise(StandardError) { config.get('loop/self.ref.inline') }
        assert_raise(StandardError) { config.get('loop/self.ref.inline_ref') }
      end
    end

    def test_concatenation
      with_fixture('config') do |fixture|
        config = config(fixture, DEFAULT_CONFIG_PATHS)
        composed = DEFAULT_CONFIG_PATHS.inject(Config.new({})) do |sum, path|
          sum + fixture.expand_path(path)
        end
        composed2 = DEFAULT_CONFIG_PATHS.inject(Config.new({})) do |sum, path|
          sum + Config.new(fixture.expand_path(path))
        end
        assert_equal composed, config
        assert_equal composed2, config
      end
    end

    def test_parent_reference
      with_config('config') do |config|
        assert_equal 'value', config.get('paths/value')
      end
    end
  end
end