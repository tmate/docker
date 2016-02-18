module MDocker
  class PathProvider < RepositoryProvider

    def initialize(file_name, repositories)
      @file_name = file_name
      @repositories = repositories
    end

    def applicable?(location)
      super(location) && location[:path]
    end

    def resolve(location)
      { paths: @repositories.map { |path| File.expand_path File.join(path, location[:path]) } }
    end

    def fetch_origin_contents(location)
      contents = location[:paths].detect do |path|
        if File.directory? path
          path = File.join path, @file_name
        end
        break File.read(path) if File.file?(path) && File.readable?(path)
      end
      raise "no file found for #{location}" if contents.nil?
      contents
    end

  end
end