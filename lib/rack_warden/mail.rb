module RackWarden
  class Mail < ::Mail::Message
    def initialize(*args)
      App.logger.debug "RW RackWarden::Mail creating new mail message with args: #{args.inspect}"
      
      mail_options = App.mail_options.dup
      
      options = args.last.is_a?(Hash) ? args.pop : {}
      super( *[args, mail_options[:delivery_options].merge(options)].flatten )
      
      _delivery_method = mail_options.delete(:via) || mail_options.delete(:delivery_method) || :test
      _delivery_options = mail_options.delete(:via_options) || mail_options.delete(:delivery_options) || {:from=>'test@localhost'}
      
      if _delivery_method.is_a?(Array)
        delivery_method *_delivery_method
        delivery_method.settings.merge _delivery_options
      else
        delivery_method _delivery_method, _delivery_options
      end
      
    end
  end
end
    
    
    