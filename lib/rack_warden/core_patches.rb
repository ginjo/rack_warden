require 'dry-types'
require 'dry/types/struct'

# Simple conversion to html (intended for yaml output)
class String
	def to_html
		self.gsub(/\n|\r/, '<br>').gsub(/  /, '&nbsp;&nbsp;')
	end
end

class Hash
	# Extract key-value pairs from self, given list of objects.
	# If last object given is hash, it will be the collector for the extracted pairs.
	# Extracted pairs are deleted from the original hash (self).
	# Returns the extracted pairs as a hash or as the supplied collector hash.
	# Attempts to ignore case.
	def extract(*args)
		other_hash = args.last.is_a?(Hash) ? args.pop : {}
		other_hash.tap do |other|
			self.delete_if {|k,v| (args.include?(k) || args.include?(k.to_s) || args.include?(k.to_s.downcase) || args.include?(k.to_sym)) || args.include?(k.to_s.downcase.to_sym) ? other[k]=v : nil}
		end
	end
	
	# Another cool way to extract without altering original:
  # def extract(*keys)
  #   Hash[[keys, self.values_at(*keys)].transpose]
  # end
  
  ## Not currently used
  # def deep_merge(other_hash)
  #   merge(other_hash) do |key, oldval, newval|
  #     case
  #     when oldval.to_s == '' && newval.to_s == ''
  #       nil
  #     when oldval.is_a?(Hash) && newval.is_a?(Hash)
  #       oldval.deep_merge(newval)
  #     when oldval == newval
  #       newval
  #     else
  #       [oldval, newval].flatten(1)
  #     end
  #   end
  # end
  
end # Hash

class Time
	def _to_unique_id
		self.to_f.to_s.delete('.').to_i.to_s(36)
	end
end

class Dry::Types::Struct
  # The original to_h changes the values.
  # This version does not change the values.
  # File 'lib/dry/types/struct.rb', line 67
  def to_hash
    self.class.schema.keys.each_with_object({}) { |key, result|
      value = self[key]
      result[key] = value   #value.respond_to?(:to_hash) ? value.to_hash : value
    }
  end
  alias_method :to_h, :to_hash
end