# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::V1::Sessions", type: :request do
  describe "POST /api/v1/auth/google" do
    let(:valid_token) { "mock_valid_token" }
    let(:invalid_token) { "mock_invalid_token" }
    let(:mock_payload) do
      {
        "sub" => "12345",
        "email" => "test@example.com",
        "name" => "Test User",
        "picture" => "https://example.com/avatar.jpg"
      }
    end
    let(:json) { JSON.parse(response.body) }

    shared_examples 'unauthorized' do |msg|
      it do
        subject
        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq(msg)
      end
    end

    before do
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_call_original
    end

    subject { post "/api/v1/auth/google", headers: headers }

    context "with valid Google ID token" do
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(valid_token, aud: ENV["GOOGLE_CLIENT_ID"])
          .and_return(mock_payload)
      end

      context "when user is new" do
        let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
        it "creates new user and returns success" do
          subject
          expect(response).to have_http_status(:ok)
          expect(json["success"]).to be true
          expect(json["message"]).to eq("Login successful")
          user = User.find_by(google_sub: "12345")
          expect(user).to be_present
          expect(user.email).to eq("test@example.com")
          expect(user.name).to eq("Test User")
          expect(user.account_type).to eq("user")
          expect(user.picture).to eq("https://example.com/avatar.jpg")
          expect(json["data"]["user"]["email"]).to eq("test@example.com")
          expect(json["data"]["user"]["name"]).to eq("Test User")
          expect(json["data"]["user"]["google_sub"]).to eq("12345")
        end
      end

      context "when user already exists" do
        let!(:existing_user) do
          create(:user, 
            google_sub: "12345",
            email: "old@example.com", 
            name: "Old Name",
            account_type: "user"
          )
        end
        let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
        it "finds existing user and returns success" do
          expect {
            subject
          }.not_to change(User, :count)
          expect(response).to have_http_status(:ok)
          expect(json["success"]).to be true
          expect(json["data"]["user"]["id"]).to eq(existing_user.id)
          expect(json["data"]["user"]["email"]).to eq("old@example.com")
          expect(json["data"]["user"]["name"]).to eq("Old Name")
        end
      end
    end

    context "with invalid Google ID token" do
      let(:headers) { { "Authorization" => "Bearer #{invalid_token}" } }
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(invalid_token, aud: ENV["GOOGLE_CLIENT_ID"])
          .and_raise(Google::Auth::IDTokens::VerificationError.new("Invalid token"))
      end
      include_examples 'unauthorized', "Invalid ID token"
    end

    context "without Authorization header" do
      let(:headers) { nil }
      include_examples 'unauthorized', "Unauthorized"
    end

    context "with malformed Authorization header" do
      context "not Bearer token" do
        let(:headers) { { "Authorization" => "Basic #{valid_token}" } }
        include_examples 'unauthorized', "Unauthorized"
      end
      context "no token provided" do
        let(:headers) { { "Authorization" => "Bearer " } }
        include_examples 'unauthorized', "Invalid ID token"
      end
    end

    context "when Google Auth service fails" do
      let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .and_raise(StandardError.new("Service unavailable"))
      end
      include_examples 'unauthorized', "Invalid ID token"
    end

    context "with Google ID token missing sub field" do
      let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(valid_token, aud: ENV["GOOGLE_CLIENT_ID"])
          .and_return(mock_payload.merge("sub" => nil))
      end
      include_examples 'unauthorized', "Invalid ID token"
    end
  end
end
