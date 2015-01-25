module RackWarden
	class Mail < ::Mail::Message
		def initialize(*args)
			
			options = args.last.is_a?(Hash) ? args.pop : {}
			super( *[args, App.mail_options[:delivery_options].dup.merge(options)].flatten )
			
			_delivery_method = App.mail_options.delete(:via) || App.mail_options.delete(:delivery_method) || :test
			_delivery_options = App.mail_options.delete(:via_options) || App.mail_options.delete(:delivery_options) || {}
			
			if _delivery_method.is_a?(Array)
				delivery_method *_delivery_method
				delivery_method.settings.merge _delivery_options
			else
				delivery_method _delivery_method, _delivery_options
			end
			
		end
	end
end
		
		
		