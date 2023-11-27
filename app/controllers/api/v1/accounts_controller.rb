# frozen_string_literal: true

module Api
  module V1
      class AccountsController < Api::V1::BaseController
        skip_before_action :authenticate_user

        def register
          @account = Account.new(account_params)
          if @account.save
            success(message: "Account created successfully", data: {account: @account, token: @account.token})
          else
            unprocessable(errors: @account.errors.messages)
          end
        end

        def login
          @account = Account.find_by(email: account_params[:email])
          if @account && @account.authenticate(account_params[:password])
            success(message: "Logged in successfully", data: {account: @account, token: @account.token})
          else
            unauthorized(message: "incorrect email/password")
          end
        end

        private
        def account_params
          params.require(:account).permit(:email, :password, :password_confirmation)
        end
      end
  end
end
