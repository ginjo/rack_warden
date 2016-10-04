require 'rom-repository'
require 'rom-sql'
require_relative 'types'


module RackWarden
  module Rom

    # Require all ruby files in a directory, recursively.
    # See http://stackoverflow.com/questions/10132949/finding-the-gem-root
    def self.load
      Dir.glob(File.join(File.dirname(__FILE__), '**', '*.rb'), &method(:require))
    end
    
    load
    
  end # Rom
end # SlackSpace