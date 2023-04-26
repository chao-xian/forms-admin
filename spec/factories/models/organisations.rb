FactoryBot.define do
  factory :organisation do
    content_id { Faker::Internet.uuid }
    slug { "test-org" }
    name { ActiveSupport::Inflector.titleize slug }

    initialize_with do
      Organisation.create_with(content_id:, name:).find_or_create_by(slug:)
    end
  end
end
