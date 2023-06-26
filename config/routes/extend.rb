scope '/' do
    # UI ==========================
    root 'static_pages#home'
    resources :sensors

    # Trigger =====================
    match '/trigger', to: 'triggers#trigger', via: 'get'


end