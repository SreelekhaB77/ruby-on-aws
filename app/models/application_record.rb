class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def generate_token(user, time = (Time.now + 1.month))
    secret = ENV['SECRET_KEY_BASE']
    @token = JWT.encode({
                          user_id: user.id,
                          email: user.email,
                          exp: time.to_i
                        }, secret)
  end

  def shout(str)
    puts "############ #{str} ############"
  end
end
