#/usr/local/bin/ruby

require 'pp'
require 'pathname'
require 'yaml'

RESOLV_TIMEOUT = 10
CURRENT_PATH = Pathname.new(__FILE__).realpath.dirname.to_s
@config = YAML.load_file(CURRENT_PATH + "/config.yml")


