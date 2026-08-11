# frozen_string_literal: true

module Api
  module V1
    class HealthController < ActionController::API
      # No authentication required for health checks
      def show
        checks = {
          database: check_database,
          redis: check_redis,
          sidekiq: check_sidekiq
        }

        all_healthy = checks.values.all? { |c| c[:status] == "connected" }

        render json: {
          status: all_healthy ? "ok" : "degraded",
          checks: checks,
          timestamp: Time.current.utc.iso8601
        }, status: all_healthy ? :ok : :service_unavailable
      end

      private

      def check_database
        ActiveRecord::Base.connection.execute("SELECT 1")
        { status: "connected" }
      rescue StandardError => e
        { status: "disconnected", error: e.message }
      end

      def check_redis
        redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
        redis.ping
        { status: "connected" }
      rescue StandardError => e
        { status: "disconnected", error: e.message }
      ensure
        redis&.close
      end

      def check_sidekiq
        # Check if Sidekiq can reach Redis (queue is operational)
        info = Sidekiq::ProcessSet.new
        { status: "connected", processes: info.size }
      rescue StandardError => e
        { status: "disconnected", error: e.message }
      end
    end
  end
end
