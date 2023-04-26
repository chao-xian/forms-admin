# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

require "factory_bot"

if HostingEnvironment.local_development? && User.none?
  Organisation.create!(content_id: "af07d5a5-df63-4ddc-9383-6a666845ebe9", slug: "government-digital-service", name: "Government Digital Service")

  # Create default super-admin
  User.create!({ email: "example@example.com",
                 organisation_slug: "government-digital-service",
                 organisation_content_id: "af07d5a5-df63-4ddc-9383-6a666845ebe9",
                 name: "A User",
                 role: :super_admin,
                 uid: "123456" })

  # create extra organisations
  test_org = FactoryBot.create :organisation, slug: "test-org"
  FactoryBot.create :organisation, slug: "ministry-of-tests"
  FactoryBot.create :organisation, slug: "department-for-testing"

  # create extra editors
  FactoryBot.create_list :user, 3, role: :editor

  # create extra super admins
  FactoryBot.create_list :user, 3, :with_super_admin
end
