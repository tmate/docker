require 'digest/sha1'
require 'yaml'

module MDocker
  class Project

    attr_reader :config

    def initialize(project_config, lock_path=nil)
      @config = project_config
      @lock_path = lock_path
    end

    def build_hash
      digest = Digest::SHA1.new
      digest.update(@config.name)
      digest = @config.images.inject(digest) do |d, image|
        d.update(image[:label])
        d.update(image[:contents])
        d.update(image[:args].to_s)
      end
      digest.hexdigest!
    end

    def run(label: 'latest', force_build:false)
      unless @config.images.find { |image| image[:label] == label }
        raise StandardError.new "image #{label} is not defined in this project"
      end
      lock = build(force: force_build)
      create_docker.run(lock[:build_name] + ':' + label)
    end

    def build(force: false)
      return read_lock unless force || needs_build?
      lock = {}
      begin
        write_lock do_build(lock)
      rescue
        do_clean(lock)
        raise
      end
    end

    def clean
      do_clean read_lock
      delete_lock
    end

    private

    def needs_build?
      lock = read_lock
      return true if lock.nil?

      docker = create_docker
      has_images = (lock[:build_images] || []).each do |info|
        _, name = info.first
        break false unless docker.has_image?(name)
      end

      !has_images || build_hash != lock[:build_hash]
    end

    def do_build(lock={})
      docker = create_docker

      lock[:build_hash] ||= build_hash
      lock[:build_name] ||= docker.generate_build_name(@config.name)
      lock[:build_images] = []

      @config.images.inject(nil) do |previous, image|
        name = "#{lock[:build_name]}:#{image[:label]}"
        rc = if image[:location][:pull]
          rc = docker.pull(image[:contents])
          rc == 0 ? docker.tag(image[:contents], name) : rc
        elsif image[:location][:tag]
          name = "#{lock[:build_name]}:#{image[:contents]}"
          docker.tag(previous, name)
        else
          contents = image[:contents]
          contents = contents.sub(/^(FROM\s.+)$/, 'FROM ' + previous) if previous
          docker.build(name, contents, image[:args])
        end
        raise StandardError.new('docker build failed') if rc != 0
        lock[:build_images] << {image[:label] => name}
        name
      end
      lock
    end

    def do_clean(lock={})
      return if lock.nil?
      docker = create_docker
      (lock[:build_images] || []).each do |info|
        _, image_name = info.first
        docker.remove(image_name)
      end
    end

    def read_lock
      begin
        YAML::load_file(@lock_path)
      rescue SystemCallError, IOError
        {}
      end
    end

    def delete_lock
      FileUtils::rm @lock_path
    end

    def write_lock(lock={})
      # todo: atomic write
      FileUtils::mkdir_p(File.dirname(@lock_path))
      File.write @lock_path, YAML::dump(lock)
      lock
    end

    def create_docker
      MDocker::Docker.new @config.effective_config
    end
  end
end