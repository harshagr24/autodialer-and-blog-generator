Rails.application.routes.draw do
  root to: redirect('/dashboard.html')

  resources :phone_numbers, only: [:index, :create]

  resources :calls, only: [:create] do
    collection do
      get :logs
    end
  end

  # Call queue management
  get 'call_queue/status', to: 'call_queue#status'
  post 'call_queue/start', to: 'call_queue#start'
  post 'call_queue/stop', to: 'call_queue#stop'

  resource :voice_settings, only: [:show, :update]
  
  post 'chat', to: 'chat#process_command'
  
  # Voice command routes
  resources :voice_commands, only: [] do
    collection do
      match :process_voice, via: [:get, :post, :options]
    end
  end
  
  # Twilio webhook
  post 'twilio/status', to: 'twilio_webhooks#call_status'

  # Blog API routes (before static files)
  get 'api/blog', to: 'blog#index'
  get 'api/blog/:id', to: 'blog#show'
  post 'api/blog/generate', to: 'blog#generate'
  delete 'api/blog/all', to: 'blog#delete_all'
  
  # Health check endpoint
  get 'health', to: -> (env) { [200, {}, ['OK']] }

  get "up" => "rails/health#show", as: :rails_health_check
end
