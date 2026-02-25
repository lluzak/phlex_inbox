module ApplicationHelper
  def reply_recipient_id(message)
    root = message.thread_root
    root.sender_id == current_contact.id ? root.recipient_id : root.sender_id
  end

  def optimistic_field_map_for(component_class)
    component_class.compiled_data[:expressions].invert.to_json
  end
end
