class ApplicationMailer < ActionMailer::Base
  default from: "Snarky Pucks Support <support@snarkypucks.com>"
  default "Reply-to" => "support@snarkypucks.com"
  default "Message-ID" => ->(v){"<#{Digest::SHA2.hexdigest(Time.now.to_i.to_s)}@snarkypucks.com>"}
  layout 'mailer'
end
