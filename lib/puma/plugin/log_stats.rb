# frozen_string_literal: true

require "puma/plugin"

module LogStats
  class << self
    # Interval between logging attempts in seconds.
    attr_accessor :interval
    LogStats.interval = 10

    attr_accessor :notify_change_with
    LogStats.notify_change_with = :sentry

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
        @previous_status_message = @status_message
        @stats = Puma.stats_hash
        @status_message = status_message
        log(@status_message) if @previous_status_message != @status_message
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

    change_level(level, "Puma threads load is greater than #{threshold * 100}% (#{max_threads - pool_capacity}/#{max_threads})")
    true
  end

  def normal_load
    change_level(:normal, "Puma threads load is back to normal values")
  end

  def change_level(level, message)
    return if @load_level == level

    log("#{level.to_s.upcase}: #{message}")
    notify(level, message)
    @load_level = level
  end

  def notify(level, message)
    if LogStats.notify_change_with == :sentry
      Sentry.capture_message(message, level: level == :critical ? :error : level) if defined?(Sentry) && level != :normal
    elsif LogStats.notify_change_with.respond_to?(:call)
      LogStats.notify_change_with.call(level: level, message: message, threads_load: threads_load)
    end
  end

  def status_message
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
