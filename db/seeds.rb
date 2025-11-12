puts "Seeding data..."

#Users
user1 = User.create!(
  google_sub: "1234567890abcde",
  name: "Taro Yamada",
  email: "taroo@example.com",
  picture: "https://example.com/avatar.png",
  account_type: "general"
)

user2 = User.create!(
  google_sub: "abcdef1234567890",
  name: "Hanako Suzuki",
  email: "hanako@example.com",
  picture: "https://example.com/avatar2.png",
  account_type: "general"
)

#Group
group = Group.create!(
  name: "家事シェア",
  share_key: "abcd1234",
  assign_mode: "manual",
  balance_type: "equal"
)

#Membership
member1 = Membership.create!(
  user: user1,
  group: group,
  role: "admin",
  active: true
)

member2 = Membership.create!(
  user: user2,
  group: group,
  role: "member",
  active: true
)

# === Tasks ===
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