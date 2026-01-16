# テスト用のデータ作成とAssignmentsController のテスト
require_relative 'config/environment'

# 既存のデータを使用
user = User.first
group = Group.first
membership = Membership.find_by(user: user, group: group)

puts "Using user: #{user.name} (#{user.email})"
puts "Using group: #{group.name}"
puts "Membership role: #{membership.role}"

# タスクを確認または作成
task = Task.find_or_create_by(name: 'Test Task', group: group) do |t|
  t.description = 'Test task description'
  t.point = 10
end
puts "Using task: #{task.name} (#{task.point} points)"

# アサインメントを確認または作成
assignment = Assignment.find_or_create_by(task: task, membership: membership) do |a|
  a.due_date = 1.week.from_now
  a.status = 'pending'
end
puts "Assignment ID: #{assignment.id}, Status: #{assignment.status}"

# JWTトークンを生成
token = JWT.encode({ user_id: user.id }, Rails.application.secret_key_base)
puts "\nJWT Token: #{token}"
puts "\nTest commands:"
puts "export BEARER_TOKEN='#{token}'"
puts "# Index assignments for task:"
puts "curl -X GET 'http://localhost:3000/api/v1/tasks/#{task.id}/assignments' -H 'Authorization: Bearer #{token}'"
puts "# Show specific assignment:"
puts "curl -X GET 'http://localhost:3000/api/v1/assignments/#{assignment.id}' -H 'Authorization: Bearer #{token}'"
