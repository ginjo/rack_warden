module RackWarden
	class Mail < ::Mail::Message
		def initialize(*args)
			super(*args)
			via=App.mail_options[:via] || :test
			via_options=App.mail_options[:via_options]
			delivery_method via, via_options
		end
	end
end
		
		
		