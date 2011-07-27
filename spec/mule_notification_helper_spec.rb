require "spec_helper"

describe MuleNotificationHelper do
  class DummyClass
  end

  before(:each) do
    @dummy_class = DummyClass.new
    @dummy_class.extend(MuleNotificationHelper)
  end

  describe "log" do
    it "will return a instance of C2DMLogger" do
      @dummy_class.log.should_not == nil
    end
  end

  describe "i_can_haz_hydra" do
    it "will return a instance of Hydra" do
      @dummy_class.i_can_haz_hydra.should_not == nil
    end

    it "the returned instance will have all the correct options set" do
      @dummy_class.i_can_haz_hydra.instance_variable_get(:@max_concurrency).should == 2
      @dummy_class.i_can_haz_hydra.instance_variable_get(:@memoize_requests).should == false
    end
  end

  describe "get_data_string" do
    it "construct a correct string from the provided map" do
      alert="this is a test message"
      badge=1
      sound="default"
      type="test_type"

      @dummy_class.get_data_string(
          {:message => alert, :badge => badge, :sound => sound, :type => type}
      ).should == "&data.message=this+is+a+test+message&data.badge=1&data.sound=default&data.type=test_type"
    end
  end

  describe "build_status" do
    it "should increase total no of responses per each call" do
      stats_map = {}
      stats_map[:test_collection] = []
      stats_map[:time] = {}
      stats_map[:time][:total] = 0.00
      stats_map[:time][:no_of_responses] = 0

      response = mock(:mock_response)
      request = mock(:mock_request)
      response.stub(:request) { request }
      response.stub(:code) { 200 }
      response.stub(:time) { 0.241 }

      r_to_n_map = {}
      r_to_n_map[request] = {}
      r_to_n_map[request][:registration_id] = "test_registration_id"
      r_to_n_map[request][:key_value_pairs] = "test_key_value_pairs"

      @dummy_class.build_status(:test_collection, response, false, false, "test description", stats_map, r_to_n_map)

      stats_map[:time][:total].should == 0.241
      stats_map[:time][:no_of_responses].should == 1
    end

    it "should populate the status map" do
      stats_map = {}
      stats_map[:test_collection] = []
      stats_map[:time] = {}
      stats_map[:time][:total] = 0.00
      stats_map[:time][:no_of_responses] = 0

      response = mock(:mock_response)
      request = mock(:mock_request)
      response.stub(:request) { request }
      response.stub(:code) { 200 }
      response.stub(:time) { 0.241 }

      r_to_n_map = {}
      r_to_n_map[request] = {}
      r_to_n_map[request][:registration_id] = "test_registration_id"
      r_to_n_map[request][:key_value_pairs] = "test_key_value_pairs"

      @dummy_class.build_status(:test_collection, response, false, false, "test description", stats_map, r_to_n_map)

      stats_map[:test_collection].count.should == 1
      stats_map[:test_collection].first[:registration_id].should == "test_registration_id"
      stats_map[:test_collection].first[:key_value_pairs].should == "test_key_value_pairs"
      stats_map[:test_collection].first[:is_error].should == false
      stats_map[:test_collection].first[:http_status_code].should == 200
      stats_map[:test_collection].first[:is_timeout?].should == false
      stats_map[:test_collection].first[:description].should == "test description"
    end
  end

  #describe "parse_push_response" do
  #  it "parse the response correctly when there is no error" do
  #    NO_ERROR_RESPONSE = "id=0:1299560247906662%f10bf81eb45e718d\n"
  #    (httparty_response = double()).stub(:parsed_response) { NO_ERROR_RESPONSE }
  #    @dummy_class.stub(:is_error?) { false }
  #
  #    result = @dummy_class.parse_response(httparty_response)
  #    result[:is_error].should == false
  #    result[:description].should == NO_ERROR_RESPONSE
  #  end
  #
  #  it "parse the response correctly when there is an error" do
  #    ERROR_RESPONSE = "Error=NotRegistered"
  #    EXTRACTED_ERROR = "NotRegistered"
  #    (httparty_response = double()).stub(:parsed_response) { ERROR_RESPONSE }
  #    @dummy_class.stub(:is_error?) { true }
  #
  #    result = @dummy_class.parse_response(httparty_response)
  #    result[:is_error].should == true
  #    result[:description].should == EXTRACTED_ERROR
  #  end
  #end
end