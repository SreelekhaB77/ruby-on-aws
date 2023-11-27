class Currency
  @req = Requester.new(ENV["FCA_URL"])


  def self.exchange(base_currency, target_currency)
    url = "latest?apikey=#{ENV["FCA_KEY"]}&base_currency=#{base_currency}&currencies=#{target_currency}"

    @req.get_request(url)
  end

  def self.get_history(currency, start, end_date)
    url = "historical?apikey=#{ENV["FCA_KEY"]}&currencies=#{currency}&date_from=#{start}&date_to=#{end_date}"

    @req.get_request(url)
  end

  def self.information(currency)
    url = "currencies?apikey=#{ENV["FCA_KEY"]}&currencies=#{currency}"

    @req.get_request(url)
  end
end