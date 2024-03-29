require "shellwords"

MAKE = Struct.new(:program_name, :program) do
  include FileUtils

  def initialize(program_name)
    super(program_name, Shellwords.split(program_name))
  end

  def [](*args, chdir: nil)
    args << "V=1" if Rake.application.options.trace
    sh(*program, *args, chdir: chdir)
  end
end.new(
  ENV['MAKE'] || ENV['make'] ||
  RbConfig::CONFIG['configure_args'][/with-make-prog\=\K\w+/] ||
  (/mswin/ =~ RUBY_PLATFORM ? 'nmake' : 'make')
)
