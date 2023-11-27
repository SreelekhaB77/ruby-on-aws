Rails.application.routes.draw do
  namespace 'api' do
    namespace 'v1' do
      post "register", to: "accounts#register"
      post "login", to: "accounts#login"

      scope "currencies" do
        get "exchange", to: "currencies#exchange"
        get "history", to: "currencies#history"
        get ":currency", to: "currencies#currency"
      end
    end
  end
end
