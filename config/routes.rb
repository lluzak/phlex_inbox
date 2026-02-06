Rails.application.routes.draw do
  root "messages#index"

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
end
