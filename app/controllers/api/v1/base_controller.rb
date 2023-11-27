# frozen_string_literal: true

module Api
  module V1
    # version 1 base controller
    class BaseController < Api::BaseController
      before_action :authenticate_user

      def authenticate_user
        authorization_header = request.headers[:authorization]
        return unauthorized({ message: 'Authorization Absent!' }) unless authorization_header

        begin
          decode_and_authenticate(authorization_header.split(' ')[1], ENV['SECRET_KEY_BASE'])
        rescue JWT::ExpiredSignature
          unauthorized({ message: 'Your session has expired' })
        rescue StandardError
          unauthorized({ message: 'Invalid token' })
        end
      end

      def decode_and_authenticate(token, secret)
        decoded_token = JWT.decode(token, secret)
        current_user = Account.find_by(id: decoded_token[0]['user_id'])

        return unauthorized({ message: 'Account not found' }) unless current_user
        @current_user = current_user
      end
    end
  end
end
