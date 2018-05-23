class PlayersController < ApplicationController
  
  before_action :require_admin
  skip_before_action :require_login, only: [:create, :new, :password_reset, :send_password_reset]
  skip_before_action :require_name, only: [:name_set, :enact_name_set]
  skip_before_action :require_admin, only: [:create, :new, :password_reset, :send_password_reset,
    :password_change, :enact_password_change, :name_set, :enact_name_set,
    :get_preferences, :set_preferences, :set_push_endpoint]
  
  def index
    @limit = 20
    @offset = (params[:offset] || 0).to_i
    @count = Player.count
    @players = Player.order(:id).limit(@limit).offset(@offset)
  end
  
  def create
    return unless ensure_account_creation_allowed && validate_name && validate_email && validate_password
    state = params[:player]
    @player = Player.find_by(email: state[:email])
    if @player
      @player.update(code: SecureRandom.base64) unless @player.code
      if @player.verified  
        Notifications.password_reset(@player).deliver_now
      else
        @player.update(name: Player.process_name(state[:name]), password: state[:password],
          password_confirmation: state[:password_confirmation])
        Notifications.verify(@player).deliver_now
      end
    else
      @player = Player.create(name: Player.process_name(state[:name]), email: state[:email], password: state[:password],
        password_confirmation: state[:password_confirmation], code: SecureRandom.base64)
      Notifications.verify(@player).deliver_now
    end
    report_success "Confirmation email sent."
  end
  
  def new
    ensure_account_creation_allowed
  end
  
  def show
    @player = Player.find(params[:id])
  end
  
  def update
    @player = Player.find(params[:id])
    state = params[:player]
    @player.name = Player.process_name(state[:name])
    @player.email = state[:email]
    @player.admin = state[:admin]
    unless state[:password].empty?
      return unless validate_password
      @player.password = state[:password]
      @player.password_confirmation = state[:password_confirmation]
    end
    @player.save
    redirect_to :back, notice: "Player updated."
  end
  
  def destroy
    Player.find(params[:id]).destroy
    redirect_to :back, notice: "Player deleted."
  end
  
  def password_reset
  end
  
  def send_password_reset
    @player = Player.find_by(email: params[:reset][:email])
    if @player
      @player.update(code: SecureRandom.base64) unless @player.code
      Notifications.password_reset(@player).deliver_now
    end
    report_success "If that address was registered, a reset email was sent."
  end
  
  def password_change
  end
  
  def enact_password_change
    return unless validate_password
    @player.update(password: params[:player][:password], password_confirmation: params[:player][:password_confirmation])
    report_success "Password changed."
  end
  
  def name_set
  end
  
  def enact_name_set
    return unless validate_name && validate_password
    state = params[:player]
    @player.update(name: Player.process_name(state[:name]), password: state[:password],
      password_confirmation: state[:password_confirmation])
    respond_to do |format|
      format.html do
        redirect = session[:name_set_redirect]
        if redirect
          session[:name_set_redirect] = nil
          redirect_to redirect, notice: "Account configured."
        else
          redirect_to :root, notice: "Account configured."
        end
      end
      format.json { render plain: "success" }
    end
  end
  
  def get_preferences
    data = { emailNotifications: (@player.email_notifications == nil ? true : @player.email_notifications) }
    render json: data
  end
  
  def set_preferences
    @player.update(email_notifications: params[:emailNotifications] == "true")
    render plain: "success"
  end
  
  def set_push_endpoint
    @player.update(push_endpoint: params[:endpoint])
    render plain: "success"
  end
  
  def invite
  end
  
  def send_invite
    return unless validate_email(:invite)
    email = params[:invite][:email]
    player = Player.find_by(email: email)
    sanitized_message = Player.sanitize(params[:invite][:message])
    if player
      if player.name
        redirect_to :back, notice: "Already registered."
      else
        player.update(code: SecureRandom.base64) unless player.code
        Notifications.invite(player, sanitized_message).deliver_now
        redirect_to :back, notice: "Invite resent."
      end
      return
    end
    password = SecureRandom.base64
    player = Player.create(email: email, password: password, password_confirmation: password, code: SecureRandom.base64)
    Notifications.invite(player, sanitized_message).deliver_now
    redirect_to :back, notice: "Invite sent."
  end
  
  private
    def ensure_account_creation_allowed
      unless Rails.configuration.x.allow_account_creation
        report_error "Account creation not allowed."
        return false
      end
      true
    end
  
    def validate_name
      length = Player.process_name(params[:player][:name]).length
      if length < Player::MIN_NAME_LENGTH
        report_error "Name must be at least #{Player::MIN_NAME_LENGTH} characters."
        return false
      end
      if length > Player::MAX_NAME_LENGTH
        report_error "Name must be no more than #{Player::MAX_NAME_LENGTH} characters."
        return false
      end
      true
    end
  
    def validate_email(key = :player)
      if !Player.valid_email?(params[key][:email])
        report_error "Please enter a valid email address."
        return false
      end
      true
    end
    
    def validate_password
      password = params[:player][:password]
      confirmation = params[:player][:password_confirmation]
      if password != confirmation
        report_error "Password and confirmation do not match."
        return false
      end
      if password.length < Player::MIN_PASSWORD_LENGTH
        report_error "Password must be at least #{Player::MIN_PASSWORD_LENGTH} characters."
        return false
      end
      true
    end
end
