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
end

class Time
	def _to_unique_id
		self.to_f.to_s.delete('.').to_i.to_s(36)
	end
end