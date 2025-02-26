require "rails_helper"

describe FormPolicy do
  subject(:policy) { described_class.new(user, form) }

  let(:organisation) { build :organisation, id: 1, slug: "gds" }
  let(:form) { build :form, organisation_id: 1, creator_id: 123 }
  let(:user) { build :user, role: :editor, organisation: }

  context "with no organisation set" do
    context "with editor role" do
      let(:user) { build :user, :with_no_org, role: :editor }

      it "raises an error" do
        expect { policy }.to raise_error FormPolicy::UserMissingOrganisationError
      end
    end

    context "with trial role" do
      let(:user) { build :user, :with_trial_role }

      it "does not raise an error" do
        expect { policy }.not_to raise_error
      end
    end
  end

  describe "#can_view_form?" do
    context "with a form editor" do
      it { is_expected.to permit_actions(%i[can_view_form]) }

      context "but from another organisation" do
        let(:organisation) { build :organisation, id: 2, slug: "non-gds" }

        it { is_expected.to forbid_actions(%i[can_view_form]) }
      end

      context "with an organisation not in the organisation table" do
        let(:user) { build :user, :with_unknown_org, role: :editor, organisation_slug: "gds" }

        it "raises an error" do
          expect { policy }.to raise_error FormPolicy::UserMissingOrganisationError
        end
      end
    end

    context "with a trial role" do
      let(:user) { build :user, :with_trial_role, id: 123 }

      context "when the user created the form" do
        it { is_expected.to permit_actions(%i[can_view_form]) }
      end

      context "when the user didn't create the form" do
        let(:user) { build :user, :with_trial_role, id: 321 }

        it { is_expected.to forbid_actions(%i[can_view_form]) }

        context "but the user belongs to the organisation that the form belongs to" do
          let(:user) { build :user, role: :trial, organisation_slug: "gds", id: 321 }

          it { is_expected.to forbid_actions(%i[can_view_form]) }
        end
      end
    end
  end

  %i[can_change_form_submission_email can_make_form_live].each do |permission|
    describe "#{permission}?" do
      context "with a form editor" do
        it { is_expected.to permit_actions(permission) }

        context "but from another organisation" do
          let(:organisation) { build :organisation, id: 2, slug: "non-gds" }

          it { is_expected.to forbid_actions(permission) }
        end
      end

      context "with a trial role" do
        let(:form) { build :form, organisation_id: nil, creator_id: 123 }

        context "when the user created the form" do
          let(:user) { build :user, :with_trial_role, id: 123 }

          it { is_expected.to forbid_actions(permission) }
        end

        context "when the user didn't create the form" do
          context "with a different user" do
            let(:user) { build :user, id: 321 }

            it { is_expected.to forbid_actions(permission) }
          end

          context "without a form creator" do
            let(:form) { build :form, organisation_id: nil, creator_id: nil }

            it { is_expected.to forbid_actions(permission) }
          end
        end
      end
    end
  end

  describe "#can_add_page_routing_conditions?" do
    let(:form) { build :form, pages:, organisation_id: 1 }
    let(:pages) { [] }

    context "and the form has one page" do
      let(:pages) { [(build :page, position: 1, id: 1)] }

      it { is_expected.to forbid_actions(%i[can_add_page_routing_conditions]) }
    end

    context "and the form has two or more pages" do
      let(:pages) { [(build :page, position: 1, id: 1), (build :page, position: 2, id: 2)] }

      context "and the form does not have a selection question" do
        it { is_expected.to forbid_actions(%i[can_add_page_routing_conditions]) }
      end

      context "and the form only has a selection question with an existing route" do
        let(:routing_conditions) { [(build :condition, id: 1, check_page_id: 1, answer_value: "Wales", goto_pageid: 2)] }
        let(:pages) { [(build :page, :with_selections_settings, position: 1, id: 1, routing_conditions:), (build :page, position: 2, id: 2)] }

        it { is_expected.to forbid_actions(%i[can_add_page_routing_conditions]) }
      end

      context "and the form has a selection question without an existing route" do
        context "and the available selection question is the last page in the form" do
          let(:routing_conditions) { [(build :condition, id: 1, check_page_id: 1, answer_value: "Wales", goto_pageid: 2)] }
          let(:pages) { [(build :page, :with_selections_settings, position: 1, id: 1, routing_conditions:), (build :page, position: 2, id: 2), (build :page, :with_selections_settings, position: 3, id: 3)] }

          it { is_expected.to forbid_actions(%i[can_add_page_routing_conditions]) }
        end

        context "and the available selection question is not the last page in the form" do
          let(:routing_conditions) { [(build :condition, id: 1, check_page_id: 1, answer_value: "Wales", goto_pageid: 2)] }
          let(:pages) { [(build :page, :with_selections_settings, position: 1, id: 1, routing_conditions:), (build :page, :with_selections_settings, position: 2, id: 2), (build :page, position: 3, id: 3)] }

          it { is_expected.to permit_actions(%i[can_add_page_routing_conditions]) }
        end
      end
    end
  end

  describe FormPolicy::Scope do
    subject(:policy_scope) { described_class.new(user, Form) }

    let(:headers) do
      {
        "X-API-Token" => Settings.forms_api.auth_key,
        "Accept" => "application/json",
      }
    end

    let(:gds_forms) { build_list :form, 2, organisation_id: 1 }

    it "uses organisation id to scope what forms a user can see" do
      organisation_id = instance_double(Integer, "organisation_id")
      scope = class_spy(Form)

      allow(user).to receive_message_chain(:organisation, :id) { organisation_id } # rubocop:disable RSpec/MessageChain

      described_class.new(user, scope).resolve

      expect(scope).to have_received(:where).with(organisation_id:)
    end

    context "with a trial user role" do
      let(:user) { build :user, :with_trial_role, id: 123 }
      let(:form) { build(:form, creator_id: 123, organisation_id: nil) }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v1/forms?creator_id=123", headers, [form].to_json, 200
        end
      end

      it "only shows forms the user created" do
        expect(policy_scope.resolve).to eq [form]
      end
    end

    context "with a non-trial user role" do
      let(:organisation) { build :organisation, id: 1, slug: "test-org" }
      let(:form) { build(:form, organisation_id: 1, creator_id: 1234) }
      let(:user) { build :user, role: :editor, organisation:, id: 123 }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v1/forms?organisation_id=1", headers, [form].to_json, 200
        end
      end

      it "only shows forms belonging to the user's organisation" do
        expect(policy_scope.resolve).to eq [form]
      end
    end

    context "with no organisation set" do
      context "with editor role" do
        let(:user) { build :user, :with_no_org, role: :editor }

        it "raises an error" do
          expect { policy }.to raise_error FormPolicy::UserMissingOrganisationError
        end
      end

      context "with trial role" do
        let(:user) { build :user, :with_trial_role }

        it "does not an error" do
          expect { policy }.not_to raise_error
        end
      end
    end

    context "with a form editor" do
      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v1/forms?organisation_id=1", headers, gds_forms.to_json, 200
        end
        policy_scope.resolve
      end

      it "Reads the forms from the API" do
        forms_request = ActiveResource::Request.new(:get, "/api/v1/forms?organisation_id=1", {}, headers)
        expect(ActiveResource::HttpMock.requests).to include forms_request
      end
    end

    context "with a user with no organisation" do
      let(:user) { build :user, :with_no_org, role: :editor }

      before do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/api/v1/forms?organisation_id=", headers, gds_forms.to_json, 200
        end
      end

      it "raises an error" do
        expect { policy_scope.resolve }.to raise_error(FormPolicy::UserMissingOrganisationError)
        forms_request = ActiveResource::Request.new(:get, "/api/v1/forms?org=", {}, headers)
        expect(ActiveResource::HttpMock.requests).not_to include forms_request
      end
    end
  end
end
