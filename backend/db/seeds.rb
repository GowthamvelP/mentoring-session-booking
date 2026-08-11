# frozen_string_literal: true

# Idempotent seed script — only seeds if database is empty.
# To force re-seed: run `rails db:seed:replant` or set FORCE_RESEED=1

if Organization.exists? && !ENV["FORCE_RESEED"]
  puts "Database already seeded (#{Organization.count} orgs, #{User.count} users, #{Slot.count} slots)."
  puts "To force re-seed, run: FORCE_RESEED=1 bin/rails db:seed"
  puts ""

  # Print quick reference for existing data
  puts "=== Quick Reference ==="
  puts "Organizations:"
  Organization.all.each { |o| puts "  #{o.name} (#{o.id}) - #{o.timezone}" }
  puts ""
  puts "Mentors:"
  User.where(role: :mentor).each { |m| puts "  #{m.name} (#{m.id}) - #{m.organization.name}" }
  puts ""
  puts "Members:"
  User.where(role: :member).each { |m| puts "  #{m.name} (#{m.id}) - #{m.organization.name}" }
  puts ""
  puts "Use these IDs as X-User-Id and X-Org-Id headers for API requests."
  exit
end

# Force reseed — clear existing data
if ENV["FORCE_RESEED"]
  puts "Force re-seeding enabled. Clearing existing data..."
  Booking.destroy_all
  Slot.destroy_all
  MentorProfile.destroy_all
  User.destroy_all
  Organization.destroy_all
end

puts "🌱 Seeding database..."

# === Organizations ===
orgs = [
  Organization.create!(name: "TechMentor Inc", timezone: "America/New_York"),
  Organization.create!(name: "Acme Corp", timezone: "America/Los_Angeles"),
  Organization.create!(name: "GlobalLearn", timezone: "Europe/London")
]

puts "  ✓ Created #{orgs.size} organizations"

# === Mentors ===
mentors_data = [
  { org: 0, name: "Sarah Chen", email: "sarah.chen@techmentor.io", bio: "Staff Engineer with 15 years in distributed systems. Previously at AWS and Stripe. Passionate about helping engineers think at scale.", expertise: ["System Design", "Distributed Systems", "Career Growth", "Technical Leadership"] },
  { org: 0, name: "Marcus Williams", email: "marcus.williams@techmentor.io", bio: "Engineering Manager turned IC. 12 years of experience. Passionate about mentoring early-career engineers and building engineering culture.", expertise: ["Ruby on Rails", "API Design", "Code Review", "Engineering Culture", "Team Building"] },
  { org: 0, name: "Elena Rodriguez", email: "elena.rodriguez@techmentor.io", bio: "Senior Platform Engineer focused on observability and reliability. Built monitoring systems for 100M+ request/day platforms.", expertise: ["Observability", "SRE", "Kubernetes", "Incident Response"] },
  { org: 1, name: "Priya Patel", email: "priya.patel@acme.io", bio: "Principal Engineer specializing in data-intensive applications and ML infrastructure. Built real-time pipelines processing 50TB/day.", expertise: ["Python", "Machine Learning", "Data Engineering", "System Architecture", "Apache Spark"] },
  { org: 1, name: "David Kim", email: "david.kim@acme.io", bio: "Full-stack architect with deep expertise in React ecosystems and frontend performance. Shipped apps used by 10M+ users.", expertise: ["React", "TypeScript", "Frontend Architecture", "Performance Optimization", "Accessibility"] },
  { org: 2, name: "James Morrison", email: "james.morrison@globallearn.io", bio: "VP of Engineering with 20 years experience across startups and enterprise. Coaches engineers on career strategy and leadership transitions.", expertise: ["Engineering Leadership", "Career Strategy", "VP/CTO Path", "Organizational Design"] },
  { org: 2, name: "Aisha Okonkwo", email: "aisha.okonkwo@globallearn.io", bio: "Security architect and former CISO. Specializes in building secure-by-default development practices and AppSec programs.", expertise: ["Application Security", "Threat Modeling", "Security Architecture", "DevSecOps"] }
]

# === Members ===
members_data = [
  { org: 0, name: "Alice Johnson", email: "alice.johnson@techmentor.io" },
  { org: 0, name: "Bob Martinez", email: "bob.martinez@techmentor.io" },
  { org: 0, name: "Charlie Park", email: "charlie.park@techmentor.io" },
  { org: 0, name: "Diana Lee", email: "diana.lee@techmentor.io" },
  { org: 1, name: "Carol Nguyen", email: "carol.nguyen@acme.io" },
  { org: 1, name: "Dan Wilson", email: "dan.wilson@acme.io" },
  { org: 1, name: "Eva Schmidt", email: "eva.schmidt@acme.io" },
  { org: 2, name: "Frank Obi", email: "frank.obi@globallearn.io" },
  { org: 2, name: "Grace Tanaka", email: "grace.tanaka@globallearn.io" }
]

mentors = []
mentors_data.each do |data|
  org = orgs[data[:org]]
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
members_data.each do |data|
  org = orgs[data[:org]]
  ActsAsTenant.with_tenant(org) do
    members << User.create!(
      organization: org,
      name: data[:name],
      email: data[:email],
      role: :member
    )
  end
end

puts "  ✓ Created #{mentors.size} mentors with profiles"
puts "  ✓ Created #{members.size} members"

# === Slots (30 days from today — dynamic, always future) ===
# Generates slots relative to Date.current so they're always valid
# regardless of when the seed is run.
slot_count = 0
base_date = Date.current + 1.day  # Start from tomorrow

mentors.each do |mentor|
  ActsAsTenant.with_tenant(mentor.organization) do
    # Generate slots for the next 30 days
    (0..29).each do |day_offset|
      date = base_date + day_offset.days
      next if date.saturday? || date.sunday? # Skip weekends

      tz = mentor.organization.timezone

      # Morning slot (9:00-10:00) — every day
      Slot.create!(
        mentor: mentor,
        organization: mentor.organization,
        start_time: date.in_time_zone(tz).change(hour: 9),
        end_time: date.in_time_zone(tz).change(hour: 10),
        status: :available
      )
      slot_count += 1

      # Mid-morning slot (11:00-12:00) — Mon/Wed/Fri
      if [1, 3, 5].include?(date.wday)
        Slot.create!(
          mentor: mentor,
          organization: mentor.organization,
          start_time: date.in_time_zone(tz).change(hour: 11),
          end_time: date.in_time_zone(tz).change(hour: 12),
          status: :available
        )
        slot_count += 1
      end

      # Afternoon slot (14:00-15:00) — every day
      Slot.create!(
        mentor: mentor,
        organization: mentor.organization,
        start_time: date.in_time_zone(tz).change(hour: 14),
        end_time: date.in_time_zone(tz).change(hour: 15),
        status: :available
      )
      slot_count += 1

      # Late afternoon slot (16:00-17:00) — Tue/Thu
      if [2, 4].include?(date.wday)
        Slot.create!(
          mentor: mentor,
          organization: mentor.organization,
          start_time: date.in_time_zone(tz).change(hour: 16),
          end_time: date.in_time_zone(tz).change(hour: 17),
          status: :available
        )
        slot_count += 1
      end
    end
  end
end

puts "  ✓ Created #{slot_count} available slots across 30 days"
puts ""
puts "🎉 Seed complete!"
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
puts "Slots are available for the next 30 days from today (#{Date.current})."
