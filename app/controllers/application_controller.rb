class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  stale_when_importmap_changes

  helper_method :current_contact

  def current_contact
    @current_contact ||= Contact.find_by!(email: "you@example.com")
  end
end
