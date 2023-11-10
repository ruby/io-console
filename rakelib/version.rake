class << (helper = Bundler::GemHelper.instance)
  def update_gemspec
    path = gemspec.loaded_from
    File.open(path, "r+b") do |f|
      d = f.read
      if d.sub!(/^(_VERSION\s*=\s*)".*"/) {$1 + gemspec.version.to_s.dump}
        f.rewind
        f.truncate(0)
        f.print(d)
      end
    end
  end

  def commit_bump
    sh(%W[git commit -m bump\ up\ to\ #{gemspec.version}
          #{gemspec.loaded_from}])
  end

  def version=(v)
    gemspec.version = v
    update_gemspec
    commit_bump
  end
end

major, minor, teeny = helper.gemspec.version.segments

desc "Bump teeny version"
task "bump:teeny" do
  helper.version = Gem::Version.new("#{major}.#{minor}.#{teeny+1}")
end

desc "Bump minor version"
task "bump:minor" do
  helper.version = Gem::Version.new("#{major}.#{minor+1}.0")
end

desc "Bump major version"
task "bump:major" do
  helper.version = Gem::Version.new("#{major+1}.0.0")
end

desc "Bump teeny version"
task "bump" => "bump:teeny"

task "tag" do
  helper.__send__(:tag_version)
end
