class Requester
  def initialize(base_url, token = nil)
    url = base_url
    @conn = Faraday.new(url:) do |f|
      f.headers['Content-Type'] = 'application/json'
      f.headers['Authorization'] = "Bearer #{token}" unless token.nil?
    end
  end

  def get_request(url, data = nil)
    response = @conn.get do |req|
      req.url url
      req.body = data.to_json
    end

    parse_response(response)
  end

  def post_request(url, data)
    response = @conn.post do |req|
      req.url url
      req.body = data.to_json
    end

    parse_response(response)
  end

  def parse_response(response)
    raise ApiRequestFailedError, response.body unless response.status == 200 || response.status == 201

    JSON.parse(response.body)
  end
end