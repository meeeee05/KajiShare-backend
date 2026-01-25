
require 'rails_helper'

RSpec.describe 'Users API', type: :request do
  let(:auth_headers) { { 'Authorization' => 'Bearer test_admin_taro' } }
  let(:invalid_headers) { { 'Authorization' => 'Bearer invalid_token' } }
  let(:json_response) { JSON.parse(response.body) }

  let!(:test_user) do
    User.find_or_create_by!(google_sub: '1234567890abcde') do |user|
      user.name = 'Test Admin'
      user.email = 'admin@example.com'
      user.account_type = 'admin'
    end
  end

  shared_examples 'status and message' do |status, message|
    it "returns #{status} and message" do
      subject
      expect(response).to have_http_status(status)
      expect(json_response['message']).to include(message) if message
    end
  end

  describe 'GET /api/v1/users' do
    subject { get '/api/v1/users', headers: headers }

    context 'without auth' do
      let(:headers) { {} }
      include_examples 'status and message', 401, 'No authentication token provided'
    end

    context 'with invalid token' do
      let(:headers) { invalid_headers }
      include_examples 'status and message', 401, 'Invalid or expired authentication token'
    end

    context 'with valid auth' do
      let(:headers) { auth_headers }
      it 'returns 200 and user info' do
        subject
        expect(response).to have_http_status(200)
        expect(response.content_type).to match(a_string_including('application/json'))
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

    subject { post '/api/v1/users', params: params }

    context 'with valid params' do
      let(:params) { valid_params }
      it 'creates user and returns 201' do
        expect { subject }.to change(User, :count).by(1)
        expect(response).to have_http_status(201)
        expect(json_response['data']['attributes']['name']).to eq('New User')
      end
    end

    context 'with invalid email' do
      let(:params) { valid_params.deep_dup.tap { |p| p[:user][:email] = 'invalid-email' } }
      it 'returns 422' do
        subject
        expect(response).to have_http_status(422)
        expect(json_response['errors']).to include('Email is invalid')
      end
    end

    context 'with duplicate email' do
      let(:params) { valid_params.deep_dup.tap { |p| p[:user][:email] = 'duplicate@example.com' } }
      before { create(:user, email: 'duplicate@example.com') }
      it 'returns 422' do
        subject
        expect(response).to have_http_status(422)
        expect(json_response['errors']).to include('Email already exists')
      end
    end

    # 異常系：必須パラメータ欠如
    context 'with missing params' do
      let(:params) { {} }
      include_examples 'status and message', 400, 'Required parameter missing: user'
    end
  end

  describe 'GET /api/v1/users/:id' do
    subject { get "/api/v1/users/#{user_id}", headers: headers }

    context 'with valid auth accessing own info' do
      let(:user_id) { test_user.id }
      let(:headers) { auth_headers }
      it 'returns user info' do
        subject
        expect(response).to have_http_status(200)
        expect(json_response['data']['attributes']['name']).to eq('Test Admin')
        expect(json_response['data']['attributes']['email']).to eq('admin@example.com')
      end
    end

    context 'accessing other users info' do
      let(:other_user) { create(:user, email: 'other@example.com', google_sub: 'other123') }
      let(:user_id) { other_user.id }
      let(:headers) { auth_headers }
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(test_user) }
      include_examples 'status and message', 403, 'You can only access your own user information'
    end

    context 'without auth' do
      let(:user_id) { test_user.id }
      let(:headers) { {} }
      include_examples 'status and message', 401, nil
    end

    context 'with non-existent user id' do
      let(:user_id) { 99999999 }
      let(:headers) { auth_headers }
      include_examples 'status and message', 404, 'User with ID'

      context 'with invalid id format' do
        let(:user_id) { 'invalid_id' }
        include_examples 'status and message', 404, 'User with ID'
      end
    end
  end

  describe 'PATCH /api/v1/users/:id' do
    let(:update_params) do
      {
        user: {
          name: 'Updated Name',
          email: 'updated@example.com'
        }
      }
    end

    subject { patch "/api/v1/users/#{user_id}", params: params, headers: headers }

    context 'with valid auth updating own info' do
      let(:user_id) { test_user.id }
      let(:params) { update_params }
      let(:headers) { auth_headers }
      it 'updates user info' do
        subject
        expect(response).to have_http_status(200)
        expect(json_response['data']['attributes']['name']).to eq('Updated Name')
        expect(json_response['data']['attributes']['email']).to eq('updated@example.com')
        test_user.reload
        expect(test_user.name).to eq('Updated Name')
        expect(test_user.email).to eq('updated@example.com')
      end
    end

    context 'with invalid params' do
      let(:user_id) { test_user.id }
      let(:params) { { user: { email: 'invalid-email' } } }
      let(:headers) { auth_headers }
      it 'returns 422 with invalid email' do
        subject
        expect(response).to have_http_status(422)
        expect(json_response['errors']).to include('Email is invalid')
      end
    end

    context 'with non-existent user id' do
      let(:user_id) { 99999999 }
      let(:params) { update_params }
      let(:headers) { auth_headers }
      include_examples 'status and message', 404, 'User with ID'
    end

    context 'updating other user info' do
      let(:other_user) { create(:user, email: 'other2@example.com', google_sub: 'other456') }
      let(:user_id) { other_user.id }
      let(:params) { update_params }
      let(:headers) { auth_headers }
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(test_user) }
      include_examples 'status and message', 403, 'You can only update your own user information'
    end
  end
end
