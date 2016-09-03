module RackWarden

  # Helper methods to be included in main app controllers.
  # Do not include this module, but rather, include the
  # specific framework module for your framework controller(s)
	module FrameworkHelpers

    extend Forwardable
    
    HelperMethods = [
      :current_user,
      :current_identity,
      :require_login,
      :warden,
      :warden_options,
      :'logged_in?',
      :'authorized?',
      :require_authorization,
      :account_widget,
      :flash_widget
    ]
    
    def_delegators :rack_warden, *HelperMethods

	  def rack_warden
	  	request.env['rack_warden_instance']
	  end
	
	end # FrameworkHelpers
end