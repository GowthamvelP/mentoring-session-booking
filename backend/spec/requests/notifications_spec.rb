# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notifications API", type: :request do
  let(:organization) { create(:organization) }
  let(:member) { create(:user, :member, organization: organization) }
  let(:mentor) { create(:user, :mentor, organization: organization) }
  let(:headers) { { "X-User-Id" => member.id, "X-Org-Id" => organization.id } }

  let!(:notification) do
    Notification.create!(
      user: member,
      organization: organization,
      notification_type: "booking_confirmed",
      title: "Session Confirmed",
      body: "Your session is confirmed.",
      read: false
    )
  end

  describe "GET /api/v1/notifications" do
    it "returns the user's notifications with unread count" do
      get "/api/v1/notifications", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].first["title"]).to eq("Session Confirmed")
      expect(json["unread_count"]).to eq(1)
    end
  end

  describe "PATCH /api/v1/notifications/:id/mark_read" do
    it "marks a notification as read" do
      patch "/api/v1/notifications/#{notification.id}/mark_read", headers: headers

      expect(response).to have_http_status(:ok)
      expect(notification.reload.read).to be true
    end
  end

  describe "POST /api/v1/notifications/mark_all_read" do
    it "marks all notifications as read" do
      Notification.create!(
        user: member,
        organization: organization,
        notification_type: "booking_cancelled",
        title: "Cancelled",
        body: "Session cancelled.",
        read: false
      )

      post "/api/v1/notifications/mark_all_read", headers: headers

      expect(response).to have_http_status(:ok)
      expect(member.notifications.unread.count).to eq(0)
    end
  end
end
