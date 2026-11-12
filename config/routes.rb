Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :quotes, only: %i[show] do
        member do
          patch :send_to_customer
          patch :approve
          patch :reject
        end
      end

      namespace :webhooks do
        patch "quotes/:id/approve", to: "quotes#approve", as: :quote_approval
        patch "quotes/:id/reject", to: "quotes#reject", as: :quote_rejection
      end
    end
  end

  mount Rswag::Api::Engine => "/api-docs"
  mount Rswag::Ui::Engine => "/api-docs"
end
