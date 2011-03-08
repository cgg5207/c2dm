require "spec_helper"

describe NotificationHelper do
  class DummyClass
  end

  before(:each) do
    @dummy_class = DummyClass.new
    @dummy_class.extend(NotificationHelper)
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

  describe "parse_push_response" do
    it "parse the response correctly when there is no error" do
      NO_ERROR_RESPONSE = "id=0:1299560247906662%f10bf81eb45e718d\n"
      (httparty_response = double()).stub(:parsed_response) { NO_ERROR_RESPONSE }
      @dummy_class.stub(:is_error?) { false }

      result = @dummy_class.parse_response(httparty_response)
      result[:is_error].should == false
      result[:description].should == NO_ERROR_RESPONSE
    end

    it "parse the response correctly when there is an error" do
      ERROR_RESPONSE = "Error=NotRegistered"
      EXTRACTED_ERROR = "NotRegistered"
      (httparty_response = double()).stub(:parsed_response) { ERROR_RESPONSE }
      @dummy_class.stub(:is_error?) { true }

      result = @dummy_class.parse_response(httparty_response)
      result[:is_error].should == true
      result[:description].should == EXTRACTED_ERROR
    end
  end
end