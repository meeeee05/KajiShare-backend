require 'rails_helper'

RSpec.describe 'Users API', type: :request do
  let(:auth_headers) { { 'Authorization' => 'Bearer test_admin_taro' } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_token' } }

  describe 'GET /api/v1/users' do
    it 'returns 401 without auth' do
      get '/api/v1/users'
      expect(response).to have_http_status(401)
      
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('No authentication token provided')
    end

    it 'returns 401 with invalid token' do
      get '/api/v1/users', headers: invalid_headers
      expect(response).to have_http_status(401)
      
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('Invalid or expired authentication token')
    end

    context 'with valid auth' do
      before do
        # テスト用ユーザーを作成（application_controllerで参照される）
        User.find_or_create_by!(google_sub: '1234567890abcde') do |user|
          user.name = 'Test Admin'
          user.email = 'admin@example.com'
          user.account_type = 'admin'
        end
      end

      it 'returns current user info' do
        get '/api/v1/users', headers: auth_headers
        
        expect(response).to have_http_status(200)
        expect(response.content_type).to match(a_string_including('application/json'))
        
        json_response = JSON.parse(response.body)
        expect(json_response['data']['attributes']['name']).to eq('Test Admin')
        expect(json_response['data']['attributes']['email']).to eq('admin@example.com')
        expect(json_response['data']['attributes']['account_type']).to eq('admin')
      end
    end
  end

  describe 'POST /api/v1/users' do
    let(:valid_params) do
      {
        user: {
          google_sub: 'new_user_123',
          name: 'New User',
          email: 'newuser@example.com',
          account_type: 'user'
        }
      }
    end

    it 'creates user with valid params' do
      expect {
        post '/api/v1/users', params: valid_params
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(201)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['attributes']['name']).to eq('New User')
      expect(json_response['data']['attributes']['email']).to eq('newuser@example.com')
      expect(json_response['data']['attributes']['account_type']).to eq('user')
    end

    it 'returns 422 with invalid email' do
      invalid_params = valid_params.deep_dup
      invalid_params[:user][:email] = 'invalid-email'

      post '/api/v1/users', params: invalid_params

      expect(response).to have_http_status(422)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include('Email is invalid')
    end

    it 'returns 422 with duplicate email' do
      create(:user, email: 'duplicate@example.com')
      
      duplicate_params = valid_params.deep_dup
      duplicate_params[:user][:email] = 'duplicate@example.com'

      post '/api/v1/users', params: duplicate_params

      expect(response).to have_http_status(422)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include('Email already exists')
    end
  end

  describe 'GET /api/v1/users/:id' do
    let(:test_user) do
      User.find_or_create_by!(google_sub: '1234567890abcde') do |user|
        user.name = 'Test Admin'
        user.email = 'admin@example.com'
        user.account_type = 'admin'
      end
    end

    context 'with valid auth accessing own info' do
      it 'returns user info' do
        get "/api/v1/users/#{test_user.id}", headers: auth_headers

        expect(response).to have_http_status(200)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['attributes']['name']).to eq('Test Admin')
        expect(json_response['data']['attributes']['email']).to eq('admin@example.com')
      end
    end

    context 'without auth' do
      it 'returns 401 unauthorized' do
        get "/api/v1/users/#{test_user.id}"

        expect(response).to have_http_status(401)
      end
    end
  end

  describe 'PATCH /api/v1/users/:id' do
    let(:test_user) do
      User.find_or_create_by!(google_sub: '1234567890abcde') do |user|
        user.name = 'Test Admin'
        user.email = 'admin@example.com'
        user.account_type = 'admin'
      end
    end

    let(:update_params) do
      {
        user: {
          name: 'Updated Name',
          email: 'updated@example.com'
        }
      }
    end

    context 'with valid auth updating own info' do
      it 'updates user info' do
        patch "/api/v1/users/#{test_user.id}", 
              params: update_params, 
              headers: auth_headers

        expect(response).to have_http_status(200)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['attributes']['name']).to eq('Updated Name')
        expect(json_response['data']['attributes']['email']).to eq('updated@example.com')

        # DBでの更新確認
        test_user.reload
        expect(test_user.name).to eq('Updated Name')
        expect(test_user.email).to eq('updated@example.com')
      end
    end

    context 'with invalid params' do
      it 'returns 422 with invalid email' do
        invalid_params = { user: { email: 'invalid-email' } }
        
        patch "/api/v1/users/#{test_user.id}", 
              params: invalid_params, 
              headers: auth_headers

        expect(response).to have_http_status(422)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Email is invalid')
      end
    end
  end
end
