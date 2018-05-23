Rails.application.routes.draw do
  get "login" => "sessions#login"
  post "login" => "sessions#create"
  post "logout" => "sessions#logout"

  get "fb_login_redirect" => "sessions#fb_login_redirect"

  get "players/invite" => "players#invite", as: :player_invite
  post "players/invite" => "players#send_invite"

  resources :players, :tracks, :games, :prompts
  
  get "reset_password" => "players#password_reset", as: :password_reset
  post "reset_password" => "players#send_password_reset"

  get "change_password" => "players#password_change", as: :password_change
  post "change_password" => "players#enact_password_change"

  get "set_name" => "players#name_set", as: :name_set
  post "set_name" => "players#enact_name_set"

  get "preferences" => "players#get_preferences"
  post "preferences" => "players#set_preferences"

  post "push_endpoint" => "players#set_push_endpoint"

  get "players/:id/login" => "sessions#login_as", as: :login_as

  post "tracks/:id/publish" => "tracks#publish", as: :publish_track
  post "tracks/:id/unpublish" => "tracks#unpublish", as: :unpublish_track
  post "track_export" => "tracks#export", as: :export_track
  
  get "track_revision/:id" => "tracks#revision", as: :track_revision
  get "published_tracks" => "tracks#published", as: :published_tracks
  
  post "games/:id/join" => "games#join", as: :join_game
  post "games/:id/leave" => "games#leave", as: :leave_game
  
  post "games/:id/invite" => "games#create_invite", as: :game_invites
  get "games/:id/invite" => "games#new_invite", as: :new_game_invite
  
  get "games/:id/last_turn" => "games#last_turn", as: :last_turn
  
  get "games/:id/resimulate/:player_id" => "games#resimulate"
  
  post "games/:id/remove_member" => "games#remove_member", as: :remove_game_member
  post "games/:id/rescind_invite" => "games#rescind_invite", as: :rescind_game_invite
  get "joined_games" => "games#joined", as: :joined_games
  get "open_games" => "games#open", as: :open_games
  
  get "canvas" => "games#canvas"
  post "canvas" => "games#canvas"
  
  get "app" => "games#app"
  
  get "notices" => "games#notices", as: :notices
  
  post "complete_tutorial" => "games#complete_tutorial", as: :complete_tutorial
  
  post "answer_game_invite" => "games#game_invite_answer", as: :game_invite_answer
  
  post "game_move" => "games#move", as: :game_move
  
  get "prompt_rankings" => "games#prompt_rankings"
  get "game_rankings" => "games#game_rankings"
  get "personal_stats" => "games#personal_stats"
  
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root "games#app"

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
