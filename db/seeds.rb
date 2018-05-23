# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# We need a 0 user for global ratings
password = SecureRandom.base64
player = Player.create(name: "Commander Bogus", email: "commander@bogus.com",
  password: password, password_confirmation: password, admin: false, verified: true)
player.update(id: 0)

