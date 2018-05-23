# Preview all emails at http://localhost:3000/rails/mailers/notifications
class NotificationsPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/notifications/verify
  def verify
    Notifications.verify
  end

  # Preview this email at http://localhost:3000/rails/mailers/notifications/password_reset
  def password_reset
    Notifications.password_reset
  end

  # Preview this email at http://localhost:3000/rails/mailers/notifications/invite
  def invite
    Notifications.invite
  end

end
