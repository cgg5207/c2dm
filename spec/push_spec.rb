require "spec_helper"

describe C2DM::Push do
  before(:all) do
    @push = C2DM::Push
  end

  describe "initialize" do
    it "when launched with correct parameters it should instantiate a instance of Push and extract the correct authentication token" do
      @push.should_receive(:post){"response"}.once
      @push.should_receive(:extract_authentication_token){"Test Auth Token"}.with("response").once
      @push.new "username", "password", "source"
    end
  end

  describe "extract_authentication_token" do
    it "should extract the authentication token when its present in the given httparty response object" do
      AUTH_TOKEN_TEST = "DQAAALUAAADIwZ-i3NEk86EdoKeel8Ld4TgDs8iTx0diowVC99ae3bF6K0gw9zz4Fk-n9FQ9qS8h26VTc44DCfdfh5KO-FshXo-8uWSSpbVmEET4mbrZgjB2g2Utq4osDLpgnS36fYh80Qcy1KttogNXpus0aq630fbJmFxK7M_6dut4QWkqN7vXR81jPcyBdIfIUgWf8UDb51xE7oe6_-YLDZaOB1D4uozjIhUQ8aJro-h9_8L-ePJx1gy92zSKB7Sz4F9c5I0"
      RESPONSE_BODY = "SID=DQAAALEAAABaaZO7Q0GfRrRRQ5uDW3yVIto3v5fY74K-25hnu7P0MREOXSjuIXWcxEyR-VR1a4TcghYjFGaksX846ac9cNZ14QS7GU-TP4QW41MFr-nakZ9EtXXWLa0zJ4_XZFUlXB38O1alca9f6YvT23kiwOwOUQYIeW9pqHgsEPZT5eH7gYh6kXHcCAVJLJ0A3fq8CqRRv28dAMF1sS0IniaYo8UJ5tiIJaXAP9EK3ahlPTMQFJrDWmrxkkJ8y_vZI0r2ROA\nLSID=DQAAALUAAABRdOKOQHuZmY6Y-4eJBj7vx6JqUUp5dIgmE0UbBrITkKRWNKlucbEpaIrfUYMGpaoSuGpzUubb-cJN2rxhqJi5DP9eFJYlOw8u3t4-u-GaZVXhObPrQZhyLO7M9EIizy4E2hIrRqNJPYewpnoqxTGEf9ygG7_mBd_0FmDDqHzNh6YifZIOMSxyTq-MOuYYWPyai1-rjH6ZK37OVfVnq50ryciP5sYs1spdeuqpxEVnqL_s-GKO6a3J-I8lLw_w4JY\nAuth=DQAAALUAAADIwZ-i3NEk86EdoKeel8Ld4TgDs8iTx0diowVC99ae3bF6K0gw9zz4Fk-n9FQ9qS8h26VTc44DCfdfh5KO-FshXo-8uWSSpbVmEET4mbrZgjB2g2Utq4osDLpgnS36fYh80Qcy1KttogNXpus0aq630fbJmFxK7M_6dut4QWkqN7vXR81jPcyBdIfIUgWf8UDb51xE7oe6_-YLDZaOB1D4uozjIhUQ8aJro-h9_8L-ePJx1gy92zSKB7Sz4F9c5I0\n"
      httparty_response = double()
      httparty_response.should_receive(:body){
        RESPONSE_BODY
      }.once

      @push.extract_authentication_token(httparty_response).should == AUTH_TOKEN_TEST
    end
  end

  describe "send_notification_with_kv_map" do
    it "should return the parsed response when there are no exceptions thrown" do
      # for init
      @push.should_receive(:post){ "test_output_for_post" }.twice #1 for init 1 for send_notif..
      @push.should_receive(:extract_authentication_token){"test_auth_token"}.once
      push_instance = @push.new("username", "password", "source")

      #for the method call
      push_instance.should_receive(:get_data_string){ "data_string_as_a_map" }.with("test_map").once
      push_instance.should_receive(:parse_push_response) { "test_processed_output" }.with("test_output_for_post").once
      push_instance.send_notification_with_kv_map("test_reg_id", "test_map").should == "test_processed_output"
    end

    it "should throw out the exception (if one occur) if handle_exceptions is false." do
      # for init
      @post_count = 0
      @push.should_receive(:post){
        if @post_count == 0
          @post_count = 1
          "test_output_for_post"
        else
          raise Exception.new
        end
      }.twice #1 for init 1 for send_notif..
      @push.should_receive(:extract_authentication_token){"test_auth_token"}.once

      #for the method call
      push_instance = @push.new("username", "password", "source")
      push_instance.should_receive(:get_data_string){ "data_string_as_a_map" }#.with("test_map").once

      lambda{ push_instance.send_notification_with_kv_map("fake_reg_id", "map", false) }.should(
          raise_error Exception
      )
    end

    it "should handle the exception (if one occur) if handle_exceptions is true." do
      # for init
      @post_count = 0
      @push.should_receive(:post){
        if @post_count == 0
          @post_count = 1
          "test_output_for_post"
        else
          raise Exception.new
        end
      }.once #1 for init 1 for send_notif..
      @push.should_receive(:extract_authentication_token){"test_auth_token"}.once

      #for the method call
      push_instance = @push.new("username", "password", "source")
      #push_instance.should_receive(:get_data_string){ "data_string_as_a_map" }.with("test_map").once

      # shouldn't raise any exception
      push_instance.send_notification_with_kv_map("fake_reg_id", "map", true)
    end
  end

  describe "send_notifications_with_kv_map" do
    before(:each) do
      @notifications = [ # contains 7 notifications
        {:registration_id => "r_id_1", :key_value_pairs => []},
        {:registration_id => "r_id_2", :key_value_pairs => []},
        {:registration_id => "r_id_3", :key_value_pairs => []},
        {:registration_id => "r_id_4", :key_value_pairs => []},
        {:registration_id => "r_id_5", :key_value_pairs => []},
        {:registration_id => "r_id_6", :key_value_pairs => []},
        {:registration_id => "r_id_7", :key_value_pairs => []},
      ]
    end

    it "should send notifications" do
      push_instance = double()
      push_instance.should_receive(:send_notification_with_kv_map).exactly(7).times

      @push.should_receive(:new){ push_instance }.once
      @push.should_receive(:clear_consecative_error_counts).exactly(7).times
      @push.should_receive(:process_response).exactly(7).times
      @push.should_receive(:manage_counts).exactly(7).times
      
      @push.send_notifications_with_kv_map("username", "password", "source", @notifications)
    end

    describe "exception handling" do
      describe "C2DM::QuotaExceededException" do
        it "should retry sending notifications" do

        end

        it "should give up after retrying for X times" do
          push_instance = double()
          push_instance.should_receive(:send_notification_with_kv_map){ puts "example response" }.exactly(7).times

          @process_count = 0
          @push.should_receive(:process_response){
            puts "count: #{@process_count}"
            if (@process_count = @process_count + 1) > 2 # 3rd time and onwards
              puts "QuotaException! count: #{@process_count}"
              raise C2DM::QuotaExceededException.new
            end
          }.exactly(7).times

          @ex_count = 0
          @push.should_receive(:handle_quota_exceeded_exception){
            if (@ex_count = @ex_count + 1) > 4 # 5th (max retries = 4) time and onwards
              false
            else
              true
            end
          }.exactly(5).times

          @push.should_receive(:new){ push_instance }.exactly(5)
          @push.should_receive(:clear_consecative_error_counts).exactly(7).times
          @push.should_receive(:manage_counts).exactly(2).times

          @push.send_notifications_with_kv_map("username", "password", "source", @notifications)
        end
      end

      describe "Timeout::Error" do
        it "should retry sending notifications" do
          push_instance = double()
          @post_count = 0
          push_instance.stub(:send_notification_with_kv_map){
            @post_count = @post_count + 1
            if @post_count == 3 # 3rd time
              raise Timeout::Error.new
            else
              "test_output_for_post"
            end
            #raise Timeout::Error.new
          }.exactly(7).times

          @timeout_count = 0
          @push.should_receive(:handle_timeout_exception) {
            if (@timeout_count = @timeout_count + 1) == 3 # 3rd time
              false
            else
              true
            end
          }
          @push.should_receive(:clear_consecative_error_counts).exactly(7).times
          @push.should_receive(:manage_counts).exactly(7).times
          @push.should_receive(:process_response).exactly(7).times
          @push.should_receive(:new){ push_instance }.exactly(2).times

          @push.send_notifications_with_kv_map("username", "password", "source", @notifications)
        end

        it "should give up after retrying for X times" do
          push_instance = double()
          @post_count = 0
          push_instance.stub(:send_notification_with_kv_map){
#            if (@post_count = @post_count + 1) == 3 # 3rd time
#              puts 'raising timeout::error'
#              ap Timeout::Error
#              raise Timeout::Error.new
#            else
#              "test_output_for_post"
#            end
            #raise_error Timeout::Error.new
            raise Timeout::Error.new
          }.exactly(7).times

          @timeout_count = 0
          @push.should_receive(:handle_timeout_exception) {
            if (@timeout_count = @timeout_count + 1) == 3 # 3rd time
              false
            else
              true
            end
          }.exactly(3).times
          #@push.should_receive(:clear_consecative_error_counts)
          #@push.should_receive(:manage_counts).exactly(7).times
          #@push.should_receive(:process_response).exactly(7).times
          @push.should_receive(:new){ push_instance }.exactly(3).times

          @push.send_notifications_with_kv_map("username", "password", "source", @notifications)
        end
      end

      describe "Timeout::ExitException" do
        it "should retry sending notifications" do
          push_instance = double()
          @post_count = 0
          push_instance.stub(:send_notification_with_kv_map){
            @post_count = @post_count + 1
            if @post_count == 3 # 3rd time
              raise Timeout::ExitException.new
            else
              "test_output_for_post"
            end
          }.exactly(7).times

          @timeout_count = 0
          @push.should_receive(:handle_timeout_exception) {
            if (@timeout_count = @timeout_count + 1) == 3 # 3rd time
              false
            else
              true
            end
          }
          @push.should_receive(:clear_consecative_error_counts).exactly(7).times
          @push.should_receive(:manage_counts).exactly(7).times
          @push.should_receive(:process_response).exactly(7).times
          @push.should_receive(:new){ push_instance }.exactly(2).times

          @push.send_notifications_with_kv_map("username", "password", "source", @notifications)
        end

        it "should give up after retrying for X times" do
          push_instance = double()
          @post_count = 0
          push_instance.stub(:send_notification_with_kv_map){
            raise Timeout::ExitException.new
          }.exactly(7).times

          @timeout_count = 0
          @push.should_receive(:handle_timeout_exception) {
            if (@timeout_count = @timeout_count + 1) == 3 # 3rd time
              false
            else
              true
            end
          }.exactly(3).times
          @push.should_receive(:new){ push_instance }.exactly(3).times

          @push.send_notifications_with_kv_map("username", "password", "source", @notifications)
        end
      end

      describe "Exception" do
        it "should give up when a unknown exception occur" do
          push_instance = double()
          @post_count = 0
          push_instance.should_receive(:send_notification_with_kv_map){
            if (@post_count = @post_count + 1) == 3 # 3rd time
              raise Exception.new
            else
              "test_output_for_post"
            end
          }.exactly(3).times

          @push.should_receive(:handle_exception ){
            false
          }.once

          @push.should_receive(:new){ push_instance }.once
          @push.should_receive(:clear_consecative_error_counts).exactly(2).times
          @push.should_receive(:process_response).exactly(2).times
          @push.should_receive(:manage_counts).exactly(2).times

          @push.send_notifications_with_kv_map("username", "password", "source", @notifications)
        end
      end
    end
  end

  describe "manage_counts" do
    before(:each) do
      @counts = {}
      @response = {}
      @response[:response] = {}
    end

    it "should work correctly when there are no errors" do
      @counts[:error_count] = 2
      @counts[:success_count] = 12
      @response[:response][:is_error] =false

      C2DM::Push.manage_counts(@counts, @response)

      @counts[:error_count].should == 2
      @counts[:success_count].should == 13
    end

    it "should work correctly when there is a error" do
      @counts[:error_count] = 5
      @counts[:success_count] = 2
      @response[:response][:is_error] =true

      C2DM::Push.manage_counts(@counts, @response)

      @counts[:error_count].should == 6
      @counts[:success_count].should == 2
    end
  end

  describe "exception handling" do
    before(:each) do
      @ex = double()
      @exceptions = double()
      @counts = {}
    end

    describe "handle_exception" do
      it "should log it and increase the exception count and ask to break" do
        @counts[:exception_count] = 2

        @ex.should_receive(:backtrace).once #logging calls this
        @push.should_receive(:log_exception).once.with(@ex, @exceptions)

        @push.handle_exception(@ex, @exceptions, @counts).should == false #brake
        @counts[:exception_count].should == 3
      end
    end

    describe "handle_timeout_exception" do
      it "should log it and increase the exception counts, and not ask to break when consecative counts are lower than 4" do
        @ex = double()
        @exceptions = double()
        @counts = {}

        @counts[:timeout_count] = 2
        @counts[:timeout_count_consecative] = 1

        @ex.should_receive(:backtrace).once #logging calls this
        @push.should_receive(:log_exception).once.with(@ex, @exceptions)

        @push.handle_timeout_exception(@ex, @exceptions, @counts).should == true

        @counts[:timeout_count].should == 3
        @counts[:timeout_count_consecative].should == 2
      end

      it "should log it and increase the exception counts, and ask to break when consecative counts are lower than 4" do
        @ex = double()
        @exceptions = double()
        @counts = {}

        @counts[:timeout_count] = 6
        @counts[:timeout_count_consecative] = 4

        @ex.should_receive(:backtrace).twice #logging calls this
        @push.should_receive(:log_exception).once.with(@ex, @exceptions)

        @push.handle_timeout_exception(@ex, @exceptions, @counts).should == false

        @counts[:timeout_count].should == 7
        @counts[:timeout_count_consecative].should == 5
      end
    end

    describe "handle_quota_exceeded_exception" do
      it "should log it and increase the exception counts, and not ask to break when consecative counts are lower than 4" do
        @ex = double()
        @exceptions = double()
        @counts = {}

        @counts[:quota_exceeded_count] = 2
        @counts[:quota_exceeded_count_consecative] = 1

        @ex.should_receive(:backtrace).once #logging calls this
        @push.should_receive(:log_exception).once.with(@ex, @exceptions)
        @push.should_receive(:sleep).once

        @push.handle_quota_exceeded_exception(@ex, @exceptions, @counts).should == true

        @counts[:quota_exceeded_count].should == 3
        @counts[:quota_exceeded_count_consecative].should == 2
      end

      it "should log it and increase the exception counts, and ask to break when consecative counts are lower than 4" do
        @ex = double()
        @exceptions = double()
        @counts = {}

        @counts[:quota_exceeded_count] = 6
        @counts[:quota_exceeded_count_consecative] = 4

        @ex.should_receive(:backtrace).twice #logging calls this
        @push.should_receive(:log_exception).once.with(@ex, @exceptions)

        @push.handle_quota_exceeded_exception(@ex, @exceptions, @counts).should == false

        @counts[:quota_exceeded_count].should == 7
        @counts[:quota_exceeded_count_consecative].should == 5
      end
    end
  end

  describe "process_response" do
    before(:each) do
      @position = 0
      @response = {}
      @response[:response] = {}
      @notification = {}
      @responses = []
    end

    it "no responses should be added in a no error situation" do
      responses_count_before = @responses.size
      @response[:response][:is_error] = false

      @push.process_response @position, @response, @notification, @responses

      @responses.size.should == responses_count_before # no responses should be added in a no error situation
    end

    it "a response should be added when there is a error" do
      responses_count_before = @responses.size
      kv_pairs = {:test => "test"}
      @response[:response][:is_error] = true
      @response[:response][:description] = "test"
      @response[:http_status_code] = 200
      @notification[:registration_id] = "test_id"
      @notification[:key_value_pairs] = kv_pairs

      @push.process_response @position, @response, @notification, @responses

      @responses.size.should == responses_count_before + 1 # a response should be added in a error situation
      r = @responses[responses_count_before] #added_response, index is responses_count_before
      r[:description].should == "test"
      r[:http_status_code].should == 200
      r[:registration_id].should == "test_id"
      r[:key_value_pairs].should == kv_pairs
    end
  end

  describe "check_for_and_raise_quota_exceeded_exception" do
    it "should raise the correct exception when the description contains a quota exceeded error" do
      response = {}
      response[:response] = {}
      response[:response][:description] = @push::C2DM_QUOTA_EXCEEDED_ERROR_MESSAGE_DESCRIPTION

      lambda{
        @push.check_for_and_raise_quota_exceeded_exception(response)
      }.should(
          raise_error(C2DM::QuotaExceededException)
      )
    end
  end

  describe "clear_consecative_error_counts" do
    it "should clear consecative error counts correctly when there is no error" do
      counts = {}
      response = {}
      response[:response] = {}
      counts[:timeout_count_consecative] = 2
      counts[:quota_exceeded_count_consecative] = 5
      response[:response][:description] = "not quota exceeded error"

      @push.clear_consecative_error_counts counts, response

      counts[:timeout_count_consecative].should == 0
      counts[:quota_exceeded_count_consecative].should == 0
    end

    it "should clear consecative error counts correctly when there is error" do
      counts = {}
      response = {}
      response[:response] = {}
      counts[:timeout_count_consecative] = 2
      counts[:quota_exceeded_count_consecative] = 5
      response[:response][:description] = @push::C2DM_QUOTA_EXCEEDED_ERROR_MESSAGE_DESCRIPTION

      @push.clear_consecative_error_counts counts, response

      counts[:timeout_count_consecative].should == 0
      counts[:quota_exceeded_count_consecative].should == 5
      response[:response][:description].should == @push::C2DM_QUOTA_EXCEEDED_ERROR_MESSAGE_DESCRIPTION
    end
  end

  describe "log_exception" do
    it "should log a given exception" do
      ex = double()
      ex.should_receive(:to_s){ "test_exception" }.once
      ex.should_receive(:backtrace){ "test_exception_backtrace" }.once
      ex_collection = []

      @push.log_exception(ex, ex_collection)

      ex_collection.size.should == 1
      ex_collection[0][:msg].should == "test_exception"
      ex_collection[0][:trace].should == "test_exception_backtrace"
    end
  end
end