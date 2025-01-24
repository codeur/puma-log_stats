# frozen_string_literal: true

require "test_helper"
require "uri"
require "puma"
require "puma/configuration"
require "puma/events"
# require "puma/launcher"

module Puma
  class TestLogStats < Minitest::Test
    HOST = "127.0.0.1"

    def test_version
      assert Puma::LogStats::VERSION
    end

    # def setup
    #   @ios_to_close = []
    # end

    # def teardown
    #   @ios_to_close.each(&:close)
    # end

    # def test_single_mode
    #   assert_log_stats(clustered: false)
    # end

    # def test_clustered_mode
    #   assert_log_stats(clustered: true)
    # end

    # private

    # def assert_log_stats(clustered: false)
    #   @tcp_port = 0
    #   uri = URI.parse("tcp://#{HOST}:#{@tcp_port}")

    #   config = Puma::Configuration.new do |c|
    #     c.workers 2 if clustered
    #     c.bind uri.to_s
    #     c.plugin :log_stats
    #     c.app do |_|
    #       sleep 1
    #       [200, {}, ["Hello"]]
    #     end
    #   end
    #   # LogStats.threshold = 1

    #   r, _ = IO.pipe
    #   events = Puma::Events.new
    #   launcher = Puma::Launcher.new(config, events: events)
    #   events.on_booted do
    #     Thread.new do
    #       uri.port = if launcher.respond_to?(:connected_port)
    #         launcher.connected_port
    #       else
    #         launcher.connected_ports.first
    #       end
    #       sock = TCPSocket.new(uri.host, uri.port)
    #       @ios_to_close << sock
    #       loop do
    #         sock << "GET / HTTP/1.0\r\n\r\n"
    #         break unless sock.gets
    #       rescue
    #         nil
    #       end
    #     end
    #   end
    #   thread = Thread.new { launcher.run }

    #   # Keep reading server-log lines until it contains a json object `{}`.
    #   # Copy output to stdout if debugging (PUMA_DEBUG=1).
    #   stdio = Puma::Events.stdio
    #   true while (log = r.gets.tap(&stdio.method(:debug))) && log !~ /{.*}/

    #   log = log.sub(/^\[\d+\] /, "")
    #   assert_equal 1, JSON.parse(log)["running"]
    # ensure
    #   launcher&.stop
    #   thread&.join
    # end
  end
end
