module RackWarden

  module Repository

    # Makes it easier to save changed models.
    def save_attributes(_id, _attrs)
      App.logger.debug "RW Repository#save_attributes (id: #{_id})"
      #App.logger.debug _attrs.to_yaml
      _attrs.delete_if {|k,v| v==nil} unless _id
      _changeset = changeset(_id, _attrs)
      #App.logger.debug "RW Repository changeset"
      #App.logger.debug _changeset.to_yaml
      case
      when _changeset.update?
        App.logger.debug "RW Repository#save_attributes update"
        App.logger.debug "RW Repository _changeset.diff"
        App.logger.debug _changeset.diff  #.to_yaml
        saved = update(_id, _changeset)
      when _changeset.create?
        App.logger.debug "RW Repository#save_attributes create"
        saved = create(_changeset)
      end
      saved
    end
  
  end # Repository

end # RackWarden