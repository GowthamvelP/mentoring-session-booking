# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < BaseController
      # GET /api/v1/notifications
      def index
        notifications = current_user.notifications.recent

        render json: {
          data: notifications.map { |n| serialize_notification(n) },
          unread_count: current_user.notifications.unread.count
        }
      end

      # PATCH /api/v1/notifications/:id/mark_read
      def mark_read
        notification = current_user.notifications.find(params[:id])
        notification.update!(read: true)
        render json: { data: serialize_notification(notification) }
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        current_user.notifications.unread.update_all(read: true)
        render json: { message: "All notifications marked as read" }
      end

      private

      def serialize_notification(n)
        {
          id: n.id,
          type: n.notification_type,
          title: n.title,
          body: n.body,
          read: n.read,
          booking_id: n.booking_id,
          created_at: n.created_at.utc.iso8601
        }
      end
    end
  end
end
