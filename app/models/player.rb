class Player < ActiveRecord::Base

  # The minimum name length.
  MIN_NAME_LENGTH = 2

  # The maximum name length.
  MAX_NAME_LENGTH = 60

  # The minimum password length.
  MIN_PASSWORD_LENGTH = 6

  # The email prefix for Facebook accounts.
  FACEBOOK_PREFIX = "facebook"

  # Strips and sanitizes a name.
  def self.process_name(name)
    sanitize(strip_name(name))
  end

  # Removes leading, trailing, and repeated spaces from the specified name.
  def self.strip_name(name)
    name.strip.squeeze(" ")
  end

  # Sanitizes text for HTML.
  def self.sanitize(text)
    text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  # Checks whether the passed string looks like a valid email address.
  def self.valid_email?(email)
    email.index("@")
  end

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :tracks, foreign_key: "creator_id", dependent: :destroy
  has_many :game_members, dependent: :destroy
  has_many :games, through: :game_members
  has_many :game_invites, dependent: :destroy
  has_many :sent_game_invites, class_name: "GameInvite", foreign_key: "sender_id", dependent: :destroy
  has_many :prompt_type_ratings, dependent: :destroy
  
  def facebook_id
    email = self.email
    self.facebook? ? email[FACEBOOK_PREFIX.length...email.length] : nil
  end
  
  def facebook?
    !Player.valid_email?(self.email) && self.email.start_with?(FACEBOOK_PREFIX)
  end
  
  def notification_email
    return nil unless self.email_notifications == nil || self.email_notifications
    self.facebook? ? self.fb_email : self.email
  end
end
