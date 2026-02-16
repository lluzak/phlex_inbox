# frozen_string_literal: true

class LiveComponentActionsController < ApplicationController
  def create
    payload = verify_token!.symbolize_keys
    component_class = payload[:c].constantize
    record = payload[:m].constantize.find(payload[:r])

    component_class.execute_action(
      params[:action_name],
      record,
      params.fetch(:params, {}).permit!.to_h
    )

    # record.reload
    # component = component_class.new(component_class.live_model_attr => record)
    # render html: ApplicationController.render(component, layout: false).html_safe, layout: false
    head :ok
  end

  private

  def verify_token!
    Rails.application.message_verifier(:live_component_action)
      .verify(params[:token], purpose: :live_component_action)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ActionController::RoutingError, "Not found"
  end
end
