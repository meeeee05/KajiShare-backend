puts "Seeding data..."

User.destroy_all
Group.destroy_all
Membership.destroy_all
Task.destroy_all
Assignment.destroy_all
Evaluation.destroy_all

#user
u1 = User.create!(google_sub: "sub_001", name: "Alice", email: "alice@example.com", picture: "https://example.com/alice.png", account_type: "standard")
u2 = User.create!(google_sub: "sub_002", name: "Bob", email: "bob@example.com", picture: "https://example.com/bob.png", account_type: "standard")

#group
g1 = Group.create!(name: "家族A", share_key: "share123", assign_mode: "manual", balance_type: "equal")

#membership
Membership.create!(user: u1, group: g1, role: "admin")
Membership.create!(user: u2, group: g1, role: "member")

#task
t1 = Task.create!(group: g1, name: "洗い物", description: "夕食後の皿洗い", frequency: "daily")
t2 = Task.create!(group: g1, name: "掃除", description: "リビングの掃除", frequency: "weekly")

#assignment
a1 = Assignment.create!(task: t1, user: u1, status: "done")
a2 = Assignment.create!(task: t2, user: u2, status: "pending")

#evaluation
Evaluation.create!(assignment: a1, user: u2, score: 5, comment: "きれいに洗えてた！")

puts "seeding completed."