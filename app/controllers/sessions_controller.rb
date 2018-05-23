require "net/http"

class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:login, :create, :fb_login_redirect]
  
  before_action :require_admin, only: :login_as
  
  def login
    logout if @player
  end

  def create
    logout if @player
    
    # handle facebook auth, if provided
    credentials = params[:credentials]
    fb_token = credentials[:fb_token]
    player = nil
    if fb_token && !fb_token.empty?
      player = facebook_login(fb_token)
      unless player
        report_error "Error authenticating with Facebook."
        return
      end
    else
      # look up player by email, attempt password authentication
      player = Player.find_by(email: credentials[:email]).try :authenticate, credentials[:password]
      unless player
        report_error "Unknown email/incorrect password."
        return
      end
      
      # make sure they're verified
      unless player.verified
        Notifications.verify(player).deliver_now
        report_error "Please follow the link in the confirmation email."
        return
      end
    end
    
    # set in session, create persistent session if requested
    session[:player_id] = player.id
    if credentials[:stay_logged_in] == "1"
      playerSession = player.sessions.create(token: SecureRandom.base64)
      cookies.permanent[:token] = playerSession.token
    end
    
    # redirect to requested page, if any
    report_success
  end

  def login_as
    session[:player_id] = params[:id]
    redirect_to :root
  end

  def fb_login_redirect
    cookies.permanent[:test] = "test"
    redirect_to "https://apps.facebook.com/" + Rails.configuration.x.fb_app_name
  end

  def logout
    # remove session information
    reset_session
  
    # remove persistent session, if present
    token = cookies[:token]
    if token
      @player.sessions.where(token: token).delete_all()
      cookies.delete(:token)
    end
    
    respond_to do |format|
      format.html { redirect_to(:login) }
      format.json { render plain: "success" }
    end
  end
  
  private
    # Handles the Facebook authentication process using the user-provided token.
    def facebook_login(fb_token)
      base_url = "https://graph.facebook.com/v2.3/" 
      creds = "&client_id=#{Rails.configuration.x.fb_app_id}&client_secret=#{Rails.configuration.x.fb_app_secret}"
      
      player = nil
      uri = URI(base_url)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        # convert to a long-term token  
        response = check_response http, (base_url +
          "oauth/access_token?grant_type=fb_exchange_token&fb_exchange_token=#{fb_token}" + creds)
        return unless response
        token = "&access_token=#{response['access_token']}"
        
        # get the player's name, id, and email
        response = check_response http, (base_url + "me?fields=id,name,email" + token)
        return unless response
        
        # find/create player record
        facebook_email = Player::FACEBOOK_PREFIX + response["id"]
        player = Player.find_by(email: facebook_email)
        if player
          player.update(name: response["name"], fb_email: response["email"])
        else
          password = SecureRandom.base64
          player = Player.create(name: response["name"], fb_email: response["email"], email: facebook_email,
            password: password, password_confirmation: password, admin: false, verified: true)
        end
      end  
      player
    end
    
    # Makes the response and returns its parsed body if successful, otherwise sets an error and returns nil.
    def check_response(http, url)
      response = http.request Net::HTTP::Get.new(url)
      return JSON.parse(response.body) if response.is_a? Net::HTTPOK
      nil
    end
    
    # Redirects to the page requested before login was enforced.
    def login_redirect
      redirect = session[:login_redirect]
      if redirect
        session[:login_redirect] = nil
        redirect_to redirect
      else
        redirect_to :root
      end
    end
    
    def report_success
      respond_to do |format|
        format.html { login_redirect }
        format.json { render plain: "success" }
      end
    end
end
