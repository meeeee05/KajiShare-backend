puts "Seeding data..."

# 既存データをクリア（必要に応じて）
puts "Clearing existing data..."
Evaluation.destroy_all
Assignment.destroy_all
Task.destroy_all
Membership.destroy_all
Group.destroy_all
User.destroy_all

#Users
user1 = User.find_or_create_by!(google_sub: "1234567890abcde") do |u|
  u.name = "Taro Yamada"
  u.email = "taroo@example.com"
  u.picture = "https://example.com/avatar.png"
  u.account_type = "general"
end

user2 = User.find_or_create_by!(google_sub: "abcdef1234567890") do |u|
  u.name = "Hanako Suzuki"
  u.email = "hanako@example.com"
  u.picture = "https://example.com/avatar2.png"
  u.account_type = "general"
end

#Group
group = Group.find_or_create_by!(name: "家事シェア") do |g|
  g.share_key = "abcd1234"
  g.assign_mode = "manual"
  g.balance_type = "equal"
end

#Membership
member1 = Membership.find_or_create_by!(
  user: user1,
  group: group
) do |m|
  m.role = "admin"
  m.active = true
end

member2 = Membership.find_or_create_by!(
  user: user2,
  group: group
) do |m|
  m.role = "member"
  m.active = true
end

#Tasks
task1 = Task.create!(
  group: group,
  name: "掃除",
  description: "リビングの掃除をする"
)

task2 = Task.create!(
  group: group,
  name: "洗濯",
  description: "服を洗濯して干す"
)

task3 = Task.create!(
  group: group,
  name: "料理",
  description: "夕食を作る"
)

#Assignment
assignment1 = Assignment.create!(
  task: task1,
  membership: member1
)

assignment2 = Assignment.create!(
  task: task2,
  membership: member2
)

#Evaluation
Evaluation.create!(
  assignment: assignment1,
  evaluator_id: member2.id,
  score: 5,
  feedback: "完璧！"
)

Evaluation.create!(
  assignment: assignment2,
  evaluator_id: member1.id,
  score: 4,
  feedback: "もう少し丁寧に干すと良いですね。"
)

puts "Seeding completed."