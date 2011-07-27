require "spec_helper"

describe C2DM::Mule do
  before(:all) do
    @mule = C2DM::Mule.new("ben", "secret", "superapp")
  end

  describe "initialize" do
    it "should init all the collections correctly" do
      mule_instance = C2DM::Mule.new("ben", "secret", "superapp")

      mule_instance.instance_variable_get(:@stats).should_not == nil
      stats = mule_instance.instance_variable_get(:@stats)

      stats[:responses].should_not == nil
      stats[:unknown_errors].should_not == nil
      stats[:timeouts].should_not == nil
      stats[:quota_exceeded].should_not == nil
      stats[:time].should_not == nil
      stats[:time][:total].should_not == nil
      stats[:time][:no_of_responses].should_not == nil
      stats[:counts].should_not == nil
      stats[:counts][:successes].should_not == nil
      stats[:counts][:retries].should_not == nil
      stats[:counts][:retries][:quota_exceeded].should_not == nil
      stats[:counts][:retries][:timeouts].should_not == nil

      mule_instance.instance_variable_get(:@notifications_to_retry).should_not == nil
      notifications_to_retry = mule_instance.instance_variable_get(:@notifications_to_retry)

      notifications_to_retry[:quota_exceeded].should_not == nil
      notifications_to_retry[:timeouts].should_not == nil

      mule_instance.instance_variable_get(:@request_to_notification_map).should_not == nil
    end
  end

  describe "schieben" do
    it "should send notifications by following the correct work flow" do
      notifications = []
      (hydra=mock(:hydra)).stub(:run)
      
      @mule.stub(:i_can_haz_hydra) { hydra }
      @mule.stub(:ready_and_queue_requests).with(notifications, hydra)
      @mule.stub(:retry_notifications)

      @mule.schieben(notifications)

    end
  end

  describe "ready_and_queue_requests" do
    it "success with no errors" do
      test_output_desc = "Test Output Desc"
      hydra = Typhoeus::Hydra.new
      response = Typhoeus::Response.new(:code => 200, :headers => "", :body => test_output_desc, :time => 0.3)
      hydra.stub(:post, C2DM::PUSH_URL).and_return(response)

      @mule.should_receive(:build_status).with(:responses, response, false, false, test_output_desc)

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      @mule.should_receive(:get_data_string).with(notification[:key_value_pairs]).once

      @mule.ready_and_queue_requests([notification], hydra)

      hydra.run
    end

    it "success with error" do
      test_output_error_msg = "TEST_ERROR_MSG"
      test_output_desc = "#{C2DM::ERROR_STRING}#{test_output_error_msg}"
      hydra = Typhoeus::Hydra.new
      response = Typhoeus::Response.new(:code => 200, :headers => "", :body => test_output_desc, :time => 0.3)
      hydra.stub(:post, C2DM::PUSH_URL).and_return(response)

      @mule.should_receive(:build_status).with(:responses, response, true, false, test_output_error_msg)

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      @mule.should_receive(:get_data_string).with(notification[:key_value_pairs]).once

      @mule.ready_and_queue_requests([notification], hydra)

      hydra.run
    end

    it "success with error quota exceeded" do
      test_output_error_msg = C2DM::C2DM_QUOTA_EXCEEDED_ERROR_MESSAGE_DESCRIPTION
      test_output_desc = "#{C2DM::ERROR_STRING}#{test_output_error_msg}"
      hydra = Typhoeus::Hydra.new
      response = Typhoeus::Response.new(:code => 200, :headers => "", :body => test_output_desc, :time => 0.3)
      hydra.stub(:post, C2DM::PUSH_URL).and_return(response)

      @mule.should_receive(:build_status).with(:quota_exceeded, response, true, false, test_output_error_msg)

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      @mule.should_receive(:get_data_string).with(notification[:key_value_pairs]).once

      @mule.ready_and_queue_requests([notification], hydra)

      hydra.run
    end

    it "should timed_out" do
      test_curl_error_msg = "Test Curl Error Message"

      hydra = Typhoeus::Hydra.new
      response = Typhoeus::Response.new(:code => 0, :headers => "", :curl_return_code => 28, :curl_error_message => test_curl_error_msg, :time => 3.21)

      hydra.stub(:post, C2DM::PUSH_URL).and_return(response)

      @mule.should_receive(:build_status).with(:timeouts, response, true, true, test_curl_error_msg)

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      @mule.should_receive(:get_data_string).with(notification[:key_value_pairs]).once

      @mule.ready_and_queue_requests([notification], hydra)

      hydra.run
    end

    it "no http response" do
      test_curl_error_msg = "Test Curl Error Message"

      hydra = Typhoeus::Hydra.new
      response = Typhoeus::Response.new(:code => 0, :headers => "", :curl_return_code => 21, :curl_error_message => test_curl_error_msg, :time => 3.21)

      hydra.stub(:post, C2DM::PUSH_URL).and_return(response)

      @mule.should_receive(:build_status).with(:unknown_errors, response, true, false, test_curl_error_msg)

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      @mule.should_receive(:get_data_string).with(notification[:key_value_pairs]).once

      @mule.ready_and_queue_requests([notification], hydra)

      hydra.run
    end

    it "http request failed" do
      test_error_msg = "Test Error Message"

      hydra = Typhoeus::Hydra.new
      response = Typhoeus::Response.new(:code => 404, :headers => "", :body => test_error_msg, :time => 1.21)

      hydra.stub(:post, C2DM::PUSH_URL).and_return(response)

      @mule.should_receive(:build_status).with(:responses, response, true, false, test_error_msg)

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      @mule.should_receive(:get_data_string).with(notification[:key_value_pairs]).once

      @mule.ready_and_queue_requests([notification], hydra)

      hydra.run
    end
  end

  describe "retry_notifications" do
    it "should follow the normal workflow" do
      stats = {}
      stats[:counts] = {}
      stats[:counts][:retries] = {}

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      collection = :test_collection

      stats[:counts][:retries][collection] = 0

      stats[collection] = []

      notifications_to_retry = {}
      notifications_to_retry[collection] = [notification]

      @mule.stub(:stats) { stats }
      @mule.stub(:notifications_to_retry) { notifications_to_retry }
      hydra = mock(:hydra)
      hydra.stub(:run).once
      @mule.stub(:i_can_haz_hydra).once { hydra }
      @mule.stub(:ready_and_queue_requests).with(notifications_to_retry[collection], hydra)

      @mule.retry_notifications collection
    end

    it "should do multiple retries if the first try fails" do
      stats = {}
      stats[:counts] = {}
      stats[:counts][:retries] = {}

      notification = {}
      notification[:registration_id] = "test_reg_id"
      notification[:key_value_pairs] = { :test => "test_value"}
      collection = :test_collection

      stats[:counts][:retries][collection] = 0

      stats[collection] = []

      notifications_to_retry = {}
      notifications_to_retry[collection] = [notification]

      notifications_to_retry[collection].stub(:clear)

      @mule.stub(:stats) { stats }
      @mule.stub(:notifications_to_retry) { notifications_to_retry }
      hydra = mock(:hydra)
      hydra.stub(:run).once
      @mule.stub(:i_can_haz_hydra).once { hydra }
      @mule.stub(:ready_and_queue_requests).with(notifications_to_retry[collection], hydra)

      @mule.retry_notifications collection

      stats[:counts][:retries][collection].should == 3
    end
  end
end