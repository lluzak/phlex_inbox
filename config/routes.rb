Rails.application.routes.draw do
  root "messages#index"

  post "live_component_actions", to: "live_component_actions#create"

  resources :messages, only: [:index, :show, :create] do
    member do
      patch :toggle_star
      patch :toggle_read
      patch :move
    end
    collection do
      get :search
      get :sent
      get :archive
      get :trash
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    get "dev/live_components", to: "dev/live_components#index"
  end
end
