module Api
  module V1
    class CurrenciesController < Api::V1::BaseController
      def exchange
        result = Currency.exchange(currency_params[:base_currency], currency_params[:target_currency])
      rescue ApiRequestFailedError => e
        unprocessable(errors: eval(e.message))
      else
        success(message: "Currency exchanged successfully", data: result["data"])
      end

      def history
        result = Currency.get_history(currency_params[:base_currency], currency_params[:from_date], currency_params[:to_date])
      rescue ApiRequestFailedError => e
        unprocessable(errors: eval(e.message))
      else
        success(message: "Currency exchanged successfully", data: result["data"])
      end

      def currency
        result = Currency.information(params[:currency])
      rescue ApiRequestFailedError => e
        unprocessable(errors: eval(e.message))
      else
        success(message: "Currency exchanged successfully", data: result["data"])
      end

      private
      def currency_params
        params.require(:currency).permit(:base_currency, :target_currency, :from_date, :to_date)
      end
    end
  end
end

