# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'home#index'

  mount API::Root => '/api'
  mount SwaggerUiEngine::Engine, at: '/api_docs'

  namespace :users do
    resources :apis, only: [:create]
    resources :taxes, only: [:create]
  end
  devise_for :users, class_name: XStocks::AR::User, controllers: { registrations: 'registrations', sessions: 'sessions' }

  resources :menu, only: [:index]

  resources :stocks, param: :symbol do
    member do
      get :initializing
      get :processing
    end
  end

  resources :watchlists

  namespace :positions do
    resources :chart, only: [:index]
    resources :excel, only: [:index]
    resources :table, only: [:index]
  end
  resources :positions, param: :symbol, only: %i[index show edit update]

  namespace :dividends do
    resources :chart, only: [:index]
    resources :excel, only: [:index]
    resources :table, only: [:index]
  end

  resources :services, param: :lookup_code, only: [:index] do
    member do
      get :run, to: 'services#run_one'
      post :run, to: 'services#submit_one'
      get :log
      get :error
      get :file
    end
    collection do
      # GET Required by Server-Sent Events feature
      get :run, to: 'services#run_all'
    end
  end

  post '/data/refresh', to: 'data#refresh', as: 'data_refresh_url'

  match '*path', to: 'application#not_found', via: :all
end
