require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::CoinmarketcapAgent do
  before(:each) do
    @valid_options = Agents::CoinmarketcapAgent.new.default_options
    @checker = Agents::CoinmarketcapAgent.new(:name => "CoinmarketcapAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
