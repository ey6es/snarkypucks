class Notifications < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.verify.subject
  #
  def verify(player)
    @player = player
    mail to: "#{@player.name} <#{@player.email}>"
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.password_reset.subject
  #
  def password_reset(player)
    @player = player
    mail to: "#{@player.name} <#{@player.email}>"
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.invite.subject
  #
  def invite(player, message)
    @player = player
    @message = message
    mail to: @player.email
  end
  
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.turn_reminder.subject
  #
  def turn_reminder(player)
    @player = player
    mail to: "#{@player.name} <#{@player.notification_email}>"
  end
end
