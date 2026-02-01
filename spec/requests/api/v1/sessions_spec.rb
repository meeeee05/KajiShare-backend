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

    # 共有処理：401エラー出力
    shared_examples 'unauthorized' do |msg|
      it do
        subject
        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq(msg)
      end
    end

    # 共通処理：Google認証を許可するテストデータ作成
    before do
      allow(Google::Auth::IDTokens).to receive(:verify_oidc).and_call_original
    end

    subject { post "/api/v1/auth/google", headers: headers }

    # 正常系：有効なGoogle IDトークンを使用
    context "with valid Google ID token" do
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(valid_token, aud: ENV["GOOGLE_CLIENT_ID"])
          .and_return(mock_payload)
      end

      # 正常系：新規ユーザー作成
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

      # 正常系：既存ユーザーでログイン
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

      # 正常系: picture欠如でも新規作成が成功し、pictureはnilになる
      context "when picture is missing" do
        let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
        before do
          allow(Google::Auth::IDTokens).to receive(:verify_oidc)
            .with(valid_token, aud: ENV["GOOGLE_CLIENT_ID"])
            .and_return(mock_payload.merge("picture" => nil))
        end
        it "creates user successfully with nil picture" do
          expect { subject }.to change(User, :count).by(1)
          expect(response).to have_http_status(:ok)
          user = User.find_by(google_sub: "12345")
          expect(user).to be_present
          expect(user.picture).to be_nil
          expect(json["success"]).to be true
          expect(json["message"]).to eq("Login successful")
        end
      end

      # 正常系: email欠如は既存ユーザーの値が維持される（新規作成はバリデーションで不可のため）
      context "when email is missing for existing user" do
        let!(:existing_user) do
          create(:user,
            google_sub: "12345",
            email: "persist@example.com",
            name: "Persisted Name",
            account_type: "user"
          )
        end
        let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
        before do
          allow(Google::Auth::IDTokens).to receive(:verify_oidc)
            .with(valid_token, aud: ENV["GOOGLE_CLIENT_ID"])
            .and_return(mock_payload.merge("email" => nil))
        end
        it "logs in and preserves existing email and name" do
          expect { subject }.not_to change(User, :count)
          expect(response).to have_http_status(:ok)
          expect(json["data"]["user"]["id"]).to eq(existing_user.id)
          expect(json["data"]["user"]["email"]).to eq("persist@example.com")
          expect(json["data"]["user"]["name"]).to eq("Persisted Name")
        end
      end

      # 正常系: name欠如は既存ユーザーの値が維持される
      context "when name is missing for existing user" do
        let!(:existing_user) do
          create(:user,
            google_sub: "12345",
            email: "persist2@example.com",
            name: "Persisted Name 2",
            account_type: "user"
          )
        end
        let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
        before do
          allow(Google::Auth::IDTokens).to receive(:verify_oidc)
            .with(valid_token, aud: ENV["GOOGLE_CLIENT_ID"])
            .and_return(mock_payload.merge("name" => nil))
        end
        it "logs in and preserves existing name and email" do
          expect { subject }.not_to change(User, :count)
          expect(response).to have_http_status(:ok)
          expect(json["data"]["user"]["email"]).to eq("persist2@example.com")
          expect(json["data"]["user"]["name"]).to eq("Persisted Name 2")
        end
      end
    end

    # 異常系：無効なGoogle IDトークンを使用
    context "with invalid Google ID token" do
      let(:headers) { { "Authorization" => "Bearer #{invalid_token}" } }
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .with(invalid_token, aud: ENV["GOOGLE_CLIENT_ID"])
          .and_raise(Google::Auth::IDTokens::VerificationError.new("Invalid token"))
      end
      include_examples 'unauthorized', "Invalid ID token"
      # エラーメッセージのみを返し、メッセージは含まれないことを確認
      it "returns only error without message for invalid token" do
        subject
        expect(json.keys).to eq(["error"])
        expect(json["message"]).to be_nil
      end
    end

    # 異常系：Authorizationヘッダーが存在しない
    context "without Authorization header" do
      let(:headers) { nil }
      include_examples 'unauthorized', "Unauthorized"
    end

    # 異常系：Authorizationヘッダーの形式が不正
    context "with malformed Authorization header" do
      context "not Bearer token" do
        let(:headers) { { "Authorization" => "Basic #{valid_token}" } }
        include_examples 'unauthorized', "Unauthorized"
      end

      # 異常系：Authorizationヘッダーのトークンが提供されていない
      context "no token provided" do
        let(:headers) { { "Authorization" => "Bearer " } }
        include_examples 'unauthorized', "Invalid ID token"
      end
    end

    # 異常系：Google認証サービスが失敗した場合
    context "when Google Auth service fails" do
      let(:headers) { { "Authorization" => "Bearer #{valid_token}" } }
      before do
        allow(Google::Auth::IDTokens).to receive(:verify_oidc)
          .and_raise(StandardError.new("Service unavailable"))
      end
      include_examples 'unauthorized', "Invalid ID token"
    end

    # 異常系：Google IDトークンにsubフィールドが存在しない
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
