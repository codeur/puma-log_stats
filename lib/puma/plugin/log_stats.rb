# frozen_string_literal: true

require "puma/plugin"

module LogStats
  class << self
    # Interval between logging attempts in seconds.
    attr_accessor :interval
    LogStats.interval = 10

    attr_accessor :alarm_on_sentry
    LogStats.alarm_on_sentry = true

    attr_accessor :alarm_notification_interval
    LogStats.alarm_notification_interval = 60

    attr_accessor :warning_threshold
    LogStats.warning_threshold = 0.7

    attr_accessor :critical_threshold
    LogStats.critical_threshold = 0.85
  end

  def start(launcher)
    @launcher = launcher
    launcher.events.register(:state) do |state|
      if %i[halt restart stop].include?(state)
        @running = false
      end
    end

    in_background do
      @running = true
      @load_level = :normal
      while @running
        sleep LogStats.interval
        @stats = Puma.stats_hash
        log(status)
        check_alarms
      end
    end
  end

  def check_alarms
    threshold_reached(:critical, LogStats.critical_threshold) ||
      threshold_reached(:warning, LogStats.warning_threshold) ||
      normal_load
  end

  def threshold_reached(level, threshold)
    return false if threads_load < threshold

    notify_alarm("#{level.to_s.upcase}: Puma threads load is more than #{threshold * 100}% (#{pool_capacity}/#{max_threads})")
    @load_level = level if @load_level != level
    true
  end

  def normal_load
    return if @load_level == :normal

    log("INFO: Puma threads load is back to normal values")
    @load_level = :normal
  end

  def notify_alarm(message)
    if (Time.now - @notified_at) < LogStats.alarm_notification_interval
      log(message)
      Sentry.capture_message(message) if LogStats.alarm_on_sentry && defined?(Sentry)
      @notified_at = Time.now
    end
  end

  def status
    if clustered?
      "cluster: #{booted_workers}/#{workers} workers: #{running}/#{max_threads} threads, #{pool_capacity} available, #{backlog} backlog"
    else
      "single: #{running}/#{max_threads} threads, #{pool_capacity} available, #{backlog} backlog"
    end
  end

  def log(str)
    @launcher.log_writer.log("[#{Time.now}][puma #{Puma::Const::VERSION}] #{str}")
  end

  def threads_load
    1.0 - pool_capacity.to_f / max_threads.to_f
  end

  def clustered?
    @stats.key?(:workers)
  end

  def workers
    @stats.fetch(:workers, 1)
  end

  def booted_workers
    @stats.fetch(:booted_workers, 1)
  end

  def running
    if clustered?
      @stats[:worker_status].sum { |s| s[:last_status].fetch(:running, 0) }
    else
      @stats.fetch(:running, 0)
    end
  end

  def backlog
    if clustered?
      @stats[:worker_status].sum { |s| s[:last_status].fetch(:backlog, 0) }
    else
      @stats.fetch(:backlog, 0)
    end
  end

  def pool_capacity
    if clustered?
      @stats[:worker_status].sum { |s| s[:last_status].fetch(:pool_capacity, 0) }
    else
      @stats.fetch(:pool_capacity, 0)
    end
  end

  def max_threads
    if clustered?
      @stats[:worker_status].sum { |s| s[:last_status].fetch(:max_threads, 0) }
    else
      @stats.fetch(:max_threads, 0)
    end
  end
end

Puma::Plugin.create do
  include LogStats
end

# require "puma"
# require "puma/plugin"
# require "json"

# # Puma plugin to log server stats whenever the number of
# # concurrent requests exceeds a configured threshold.
# module LogStats
#   STAT_METHODS = %i[backlog running pool_capacity max_threads requests_count].freeze

#   class << self
#     # Minimum concurrent requests per process that will trigger logging server
#     # stats, or nil to disable logging.
#     # Default is the max number of threads in the server's thread pool.
#     # If this attribute is a Proc, it will be re-evaluated each interval.
#     attr_accessor :threshold
#     LogStats.threshold = :max

#     # Interval between logging attempts in seconds.
#     attr_accessor :interval
#     LogStats.interval = 1

#     # Proc to filter backtraces.
#     attr_accessor :backtrace_filter
#     LogStats.backtrace_filter = ->(bt) { bt }
#   end

#   Puma::Plugin.create do
#     attr_reader :launcher

#     def start(launcher)
#       @launcher = launcher
#       launcher.events.register(:state) do |state|
#         @state = state
#         stats_logger_thread if state == :running
#       end

#       in_background { start }
#     end

#     private

#     def stats_logger_thread
#       Thread.new do
#         if Thread.current.respond_to?(:name=)
#           Thread.current.name = "puma stats logger"
#         end
#         start while @state == :running
#       end
#     end

#     def start
#       sleep LogStats.interval
#       return unless server

#       if should_log?
#         stats = server_stats
#         stats[:threads] = thread_backtraces
#         stats[:gc] = GC.stat
#         log stats.to_json
#       end
#     rescue => e
#       log "LogStats failed: #{e}\n  #{e.backtrace.join("\n    ")}"
#     end

#     def log(str)
#       launcher.log_writer.log str
#     end

#     # Save reference to Server object from the thread-local key.
#     def server
#       @server ||= Thread.list.map { |t| t[Puma::Server::ThreadLocalKey] }.compact.first
#     end

#     def server_stats
#       STAT_METHODS.select(&server.method(:respond_to?))
#         .map { |name| [name, server.send(name) || 0] }.to_h
#     end

#     # True if current server load meets configured threshold.
#     def should_log?
#       threshold = LogStats.threshold
#       threshold = threshold.call if threshold.is_a?(Proc)
#       threshold = server.max_threads if threshold == :max
#       threshold && (server.max_threads - server.pool_capacity) >= threshold
#     end

#     def thread_backtraces
#       worker_threads.map do |t|
#         name = t.respond_to?(:name) ? t.name : thread.object_id.to_s(36)
#         [name, LogStats.backtrace_filter.call(t.backtrace)]
#       end.sort.to_h
#     end

#     # List all non-idle worker threads in the thread pool.
#     def worker_threads
#       server.instance_variable_get(:@thread_pool)
#         .instance_variable_get(:@workers)
#         .reject { |t| t.backtrace.first.match?(/thread_pool\.rb.*sleep/) }
#     end
#   end
# end
