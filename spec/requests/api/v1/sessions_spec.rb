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

    before do
      # Mock Google::Auth::IDTokens.verify_oidc
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_call_original
    end

    context "with valid Google ID token" do
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(valid_token, aud: ENV["GOOGLE_CLIENT_ID"])
          .and_return(mock_payload)
      end

      context "when user is new" do
        it "creates new user and returns success" do
          post "/api/v1/auth/google",
               headers: { "Authorization" => "Bearer #{valid_token}" }
          
          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          expect(json_response["success"]).to be true
          expect(json_response["message"]).to eq("Login successful")
          
          # ユーザーが作成されたことを確認
          user = User.find_by(google_sub: "12345")
          expect(user).to be_present
          expect(user.email).to eq("test@example.com")
          expect(user.name).to eq("Test User")
          expect(user.account_type).to eq("user")
          expect(user.picture).to eq("https://example.com/avatar.jpg")
          
          # レスポンスデータの確認
          expect(json_response["data"]["user"]["email"]).to eq("test@example.com")
          expect(json_response["data"]["user"]["name"]).to eq("Test User")
          expect(json_response["data"]["user"]["google_sub"]).to eq("12345")
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

        it "finds existing user and returns success" do
          expect {
            post "/api/v1/auth/google",
                 headers: { "Authorization" => "Bearer #{valid_token}" }
          }.not_to change(User, :count)

          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          expect(json_response["success"]).to be true
          expect(json_response["data"]["user"]["id"]).to eq(existing_user.id)
          # 既存ユーザーの情報は更新されない
          expect(json_response["data"]["user"]["email"]).to eq("old@example.com")
          expect(json_response["data"]["user"]["name"]).to eq("Old Name")
        end
      end
    end

    context "with invalid Google ID token" do
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(invalid_token, aud: ENV["GOOGLE_CLIENT_ID"])
          .and_raise(Google::Auth::IDTokens::VerificationError.new("Invalid token"))
      end

      it "returns unauthorized status" do
        post "/api/v1/auth/google",
             headers: { "Authorization" => "Bearer #{invalid_token}" }

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Invalid ID token")
      end
    end

    context "without Authorization header" do
      it "returns unauthorized status" do
        post "/api/v1/auth/google"

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Unauthorized")
      end
    end

    context "with malformed Authorization header" do
      it "returns unauthorized status when not Bearer token" do
        post "/api/v1/auth/google",
             headers: { "Authorization" => "Basic #{valid_token}" }

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Unauthorized")
      end

      it "returns unauthorized status when no token provided" do
        post "/api/v1/auth/google",
             headers: { "Authorization" => "Bearer " }

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Invalid ID token")
      end
    end

    context "when Google Auth service fails" do
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .and_raise(StandardError.new("Service unavailable"))
      end

      it "handles service errors gracefully" do
        post "/api/v1/auth/google",
             headers: { "Authorization" => "Bearer #{valid_token}" }

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Invalid ID token")
      end
    end
  end
end
