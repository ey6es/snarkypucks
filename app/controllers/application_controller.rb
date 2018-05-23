class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  before_action :require_login, :require_name
  
  protected
    # Ensures that we have a @player object.
    def require_login
      get_login
      return if @player
      
      # otherwise, redirect to login page
      session[:login_redirect] = request.fullpath
      redirect_to(:login)
    end
    
    # Fetches the player object if available, but doesn't require it.
    def get_login
      # look for existing session
      player_id = session[:player_id]
      if player_id
        @player = Player.find_by(id: player_id)
        return if @player
      end
      
      # check for a persistent session
      token = cookies[:token]
      if token
        playerSession = Session.find_by(token: token)
        if playerSession
          @player = playerSession.player
          if @player
            session[:player_id] = @player.id
            return
          end
        end
      end
      
      # check for an email code
      player_id = params[:player_id]
      code = params[:code]
      if player_id && code
        @player = Player.find_by(id: player_id, code: code)
        if @player
          session[:player_id] = @player.id
          @player.update(code: nil, verified: true)
          flash.now[:notice] = "Address verified." if params[:verified] 
          return
        end
      end
    end
    
    # Requires that the player have a name, if there's a player.
    def require_name
      return if !@player || @player.name
      session[:name_set_redirect] = request.fullpath
      redirect_to(:name_set) and return false
    end
    
    # Ensures that our @player is an admin.
    def require_admin
      redirect_to :root and return false unless @player.try(:admin)
    end
    
    def report_success(message)
      respond_to do |format|
        format.html { redirect_to :back, notice: message }
        format.json { render plain: "success" }
      end
    end
    
    def report_error(message)
      respond_to do |format|
        format.html { redirect_to :back, notice: message }
        format.json { render plain: message }
      end
    end
end
