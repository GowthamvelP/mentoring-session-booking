# frozen_string_literal: true

puts "Seeding database..."

# Clear existing data in reverse dependency order
Booking.destroy_all
Slot.destroy_all
MentorProfile.destroy_all
User.destroy_all
Organization.destroy_all

# === Organizations ===
orgs = [
  Organization.create!(name: "TechMentor Inc", timezone: "America/New_York"),
  Organization.create!(name: "Acme Corp", timezone: "America/Los_Angeles")
]

puts "  Created #{orgs.size} organizations"

# === Users (Mentors) ===
mentors_data = [
  { name: "Sarah Chen", email: "sarah.chen@techmentor.io", bio: "Staff Engineer with 15 years in distributed systems. Previously at AWS and Stripe.", expertise: ["System Design", "Distributed Systems", "Career Growth", "Technical Leadership"] },
  { name: "Marcus Williams", email: "marcus.williams@techmentor.io", bio: "Engineering Manager turned IC. Passionate about mentoring early-career engineers.", expertise: ["Ruby on Rails", "API Design", "Code Review", "Engineering Culture"] },
  { name: "Priya Patel", email: "priya.patel@acme.io", bio: "Principal Engineer specializing in data-intensive applications and ML infrastructure.", expertise: ["Python", "Machine Learning", "Data Engineering", "System Architecture"] },
  { name: "David Kim", email: "david.kim@acme.io", bio: "Full-stack architect with deep expertise in React ecosystems and frontend performance.", expertise: ["React", "TypeScript", "Frontend Architecture", "Performance Optimization"] }
]

# === Users (Members) ===
members_data = [
  { name: "Alice Johnson", email: "alice.johnson@techmentor.io" },
  { name: "Bob Martinez", email: "bob.martinez@techmentor.io" },
  { name: "Carol Nguyen", email: "carol.nguyen@acme.io" },
  { name: "Dan Wilson", email: "dan.wilson@acme.io" }
]

mentors = []
mentors_data.each_with_index do |data, i|
  org = i < 2 ? orgs[0] : orgs[1]
  ActsAsTenant.with_tenant(org) do
    user = User.create!(
      organization: org,
      name: data[:name],
      email: data[:email],
      role: :mentor
    )
    MentorProfile.create!(
      user: user,
      bio: data[:bio],
      expertise: data[:expertise]
    )
    mentors << user
  end
end

members = []
members_data.each_with_index do |data, i|
  org = i < 2 ? orgs[0] : orgs[1]
  ActsAsTenant.with_tenant(org) do
    members << User.create!(
      organization: org,
      name: data[:name],
      email: data[:email],
      role: :member
    )
  end
end

puts "  Created #{mentors.size} mentors with profiles"
puts "  Created #{members.size} members"

# === Slots (20+ available slots across next 7 days) ===
slot_count = 0
base_date = Date.tomorrow

mentors.each do |mentor|
  ActsAsTenant.with_tenant(mentor.organization) do
    # Create 5-6 slots per mentor across the next 7 days
    (0..6).each do |day_offset|
      date = base_date + day_offset.days
      next if date.saturday? || date.sunday? # Skip weekends

      # Morning slot (9:00-10:00)
      if day_offset.even?
        Slot.create!(
          mentor: mentor,
          organization: mentor.organization,
          start_time: date.in_time_zone(mentor.organization.timezone).change(hour: 9),
          end_time: date.in_time_zone(mentor.organization.timezone).change(hour: 10),
          status: :available
        )
        slot_count += 1
      end

      # Afternoon slot (14:00-15:00)
      Slot.create!(
        mentor: mentor,
        organization: mentor.organization,
        start_time: date.in_time_zone(mentor.organization.timezone).change(hour: 14),
        end_time: date.in_time_zone(mentor.organization.timezone).change(hour: 15),
        status: :available
      )
      slot_count += 1

      # Late afternoon slot (16:00-17:00) on odd days
      if day_offset.odd?
        Slot.create!(
          mentor: mentor,
          organization: mentor.organization,
          start_time: date.in_time_zone(mentor.organization.timezone).change(hour: 16),
          end_time: date.in_time_zone(mentor.organization.timezone).change(hour: 17),
          status: :available
        )
        slot_count += 1
      end
    end
  end
end

puts "  Created #{slot_count} available slots across 7 days"
puts ""
puts "Seed complete!"
puts ""
puts "=== Quick Reference ==="
puts "Organizations:"
orgs.each { |o| puts "  #{o.name} (#{o.id}) - #{o.timezone}" }
puts ""
puts "Mentors:"
mentors.each { |m| puts "  #{m.name} (#{m.id}) - #{m.organization.name}" }
puts ""
puts "Members:"
members.each { |m| puts "  #{m.name} (#{m.id}) - #{m.organization.name}" }
puts ""
puts "Use these IDs as X-User-Id and X-Org-Id headers for API requests."
