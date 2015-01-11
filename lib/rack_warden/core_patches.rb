# Simple conversion to html (intended for yaml output)
class String
	def to_html
		self.gsub(/\n|\r/, '<br>').gsub(/  /, '&nbsp;&nbsp;')
	end
end