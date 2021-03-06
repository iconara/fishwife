#--
# Copyright (c) 2011-2015 David Kellum
# Copyright (c) 2010-2011 Don Werve
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You may
# obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'spec_helper'
require 'test_app'
require 'thread'
require 'digest/md5'
require 'base64'
require 'json'

describe Fishwife do
  def get(path, headers = {})
    Net::HTTP.start(@options[:host], @options[:port]) do |http|
      request = Net::HTTP::Get.new(path, headers)
      http.request(request)
    end
  end

  def post(path, params = nil, headers = {}, body = nil)
    Net::HTTP.start(@options[:host], @options[:port]) do |http|
      request = Net::HTTP::Post.new(path, headers)
      request.form_data = params if params
      if body
        if body.respond_to?( :read )
          request.body_stream = body
        else
          request.body = body
        end
      end
      http.request(request)
    end
  end

  before(:all) do
    @lock = Mutex.new
    @app = Rack::Lint.new(TestApp.new)
    @options = { :host => '127.0.0.1',
                 :port => 9201,
                 :request_body_ram => 256,
                 :request_body_max => 96 * 1024,
                 :request_body_tmpdir => File.dirname( __FILE__ ) }
    Net::HTTP.version_1_2
    @server = Fishwife::HttpServer.new(@options)
    @server.start(@app)
  end

  after(:all) do
    @server.stop
    @server.join
  end

  it "returns 200 OK" do
    response = get("/ping")
    response.code.should == "200"
  end

  it "returns 403 FORBIDDEN" do
    response = get("/error/403")
    response.code.should == "403"
  end

  it "returns 404 NOT FOUND" do
    response = get("/jimmy/hoffa")
    response.code.should == "404"
  end

  it "sets Rack headers" do
    response = get("/echo")
    response.code.should == "200"
    content = JSON.parse(response.body)
    content["rack.multithread"].should be_true
    content["rack.multiprocess"].should be_false
    content["rack.run_once"].should be_false
  end

  it "passes form variables via GET" do
    response = get("/echo?answer=42")
    response.code.should == "200"
    content = JSON.parse(response.body)
    content['request.params']['answer'].should == '42'
  end

  it "passes form variables via POST" do
    question = "What is the answer to life, the universe, and everything?"
    response = post("/echo", 'question' => question)
    response.code.should == "200"
    content = JSON.parse(response.body)
    content['request.params']['question'].should == question
  end

  it "Passes along larger non-form POST body" do
    body = '<' + "f" * (93*1024) + '>'
    headers = { "Content-Type" => "text/plain" }
    response = post("/dcount", nil, headers, body)
    response.code.should == "200"
    response.body.to_i.should == body.size * 2
  end

  it "Passes along larger non-form POST body when chunked" do
    body = '<' + "f" * (93*1024) + '>'
    headers = { "Content-Type" => "text/plain",
                "Transfer-Encoding" => "chunked" }
    response = post("/dcount", nil, headers, StringIO.new( body ) )
    response.code.should == "200"
    response.body.to_i.should == body.size * 2
 end

  it "Rejects request body larger than maximum" do
    body = '<' + "f" * (100*1024) + '>'
    headers = { "Content-Type" => "text/plain" }
    response = post("/count", nil, headers, body)
    response.code.should == "413"
  end

  it "Rejects request body larger than maximum in chunked request" do
    body = '<' + "f" * (100*1024) + '>'
    headers = { "Content-Type" => "text/plain",
                "Transfer-Encoding" => "chunked" }
    response = post("/count", nil, headers, StringIO.new( body ) )
    response.code.should == "413"
  end

  it "passes custom headers" do
    response = get("/echo", "X-My-Header" => "Pancakes")
    response.code.should == "200"
    content = JSON.parse(response.body)
    content["HTTP_X_MY_HEADER"].should == "Pancakes"
  end

  it "returns multiple values of the same header" do
    response = get("/multi_headers")
    response['Warning'].should == "warn-1, warn-2"
    # Net::HTTP handle multiple headers with join( ", " )
  end

  it "lets the Rack app know it's running as a servlet" do
    response = get("/echo", 'answer' => '42')
    response.code.should == "200"
    content = JSON.parse(response.body)
    content['rack.java.servlet'].should be_true
  end

  it "is clearly Jetty" do
    response = get("/ping")
    response['server'].should =~ /jetty/i
  end

  it "sets the server port and hostname" do
    response = get("/echo")
    content = JSON.parse(response.body)
    content["SERVER_PORT"].should == "9201"
    content["SERVER_NAME"].should == "127.0.0.1"
  end

  it "passes the URI scheme" do
    response = get("/echo")
    content = JSON.parse(response.body)
    content['rack.url_scheme'].should == 'http'
  end

  it "supports file downloads" do
    response = get("/download")
    response.code.should == "200"
    response['Content-Type'].should == 'image/png'
    checksum = Digest::MD5.hexdigest(response.body)
    checksum.should == '8da4b60a9bbe205d4d3699985470627e'
  end

  it "supports file uploads" do
    boundary = '349832898984244898448024464570528145'
    content = []
    content << "--#{boundary}"
    content << 'Content-Disposition: form-data; name="file"; ' +
      'filename="reddit-icon.png"'
    content << 'Content-Type: image/png'
    content << 'Content-Transfer-Encoding: base64'
    content << ''
    content <<
      Base64.encode64( File.read('spec/data/reddit-icon.png') ).strip
    content << "--#{boundary}--"
    body = content.map { |l| l + "\r\n" }.join('')
    headers = { "Content-Type" =>
      "multipart/form-data; boundary=#{boundary}" }
    response = post("/upload", nil, headers, body)
    response.code.should == "200"
    response.body.should == '8da4b60a9bbe205d4d3699985470627e'
  end

  it "handles async requests" do
    pending "Causes intermittent 30s pauses, TestApp.push/pull is sketchy"
    lock = Mutex.new
    buffer = Array.new

    clients = 10.times.map do |index|
      Thread.new do
        Net::HTTP.start(@options[:host], @options[:port]) do |http|
          response = http.get("/pull")
          lock.synchronize {
            buffer << "#{index}: #{response.body}" }
        end
      end
    end

    lock.synchronize { buffer.should be_empty }
    post("/push", 'message' => "one")
    clients.each { |c| c.join }
    lock.synchronize { buffer.should_not be_empty }
    lock.synchronize { buffer.count.should == 10 }
  end

end
