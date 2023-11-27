# frozen_string_literal: true

module Api
  # Base Api Controller
  class BaseController < ApplicationController
    def success(data)
      render json: {
        status: 'success',
        message: data[:message],
        data: data[:data]
      }, status: 200
    end

    def unprocessable(data)
      render json: {
        status: 'unprocessable',
        message: data[:message],
        data: data[:errors]
      }, status: :unprocessable_entity
    end

    def unauthorized(data)
      render json: {
        status: 'unauthorized',
        message: data[:message],
        data: data[:data]
      }, status: :unauthorized
    end

    def server_error(data)
      render json: {
        status: 'server error',
        message: data[:message]
      }, status: 500
    end

    def conflict(data)
      render json: {
        status: 'conflicting',
        message: data[:message]
      }, status: 409
    end

    def notfound(data)
      render json: {
        status: 'not found',
        message: data[:message],
        data: data[:data]
      }, status: :not_found
    end

    def bad_request(data)
      render json: {
        status: 'bad request',
        message: data[:message]
      }, status: :bad_request
    end

    def payment_required(data)
      render json: {
        status: 'payment required',
        message: data[:message]
      }, status: 402
    end

    def shout(str)
      puts "############ #{str} ############"
    end
  end
end