class AddEmailToPlayer < ActiveRecord::Migration
  def change
    add_column :players, :fb_email, :string
    add_column :players, :email_notifications, :boolean
    add_column :players, :push_endpoint, :string
  end
end
