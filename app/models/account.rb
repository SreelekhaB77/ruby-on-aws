class Account < ApplicationRecord
  has_secure_password

  validates_uniqueness_of :email

  def token
    generate_token(self)
  end
end
