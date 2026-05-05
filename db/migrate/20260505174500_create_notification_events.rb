class CreateNotificationEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_events do |t|
      t.string :event_type, null: false
      t.bigint :recipient_user_id, null: false
      t.bigint :actor_user_id
      t.bigint :group_id
      t.bigint :task_id
      t.bigint :assignment_id
      t.datetime :occurred_at, null: false
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :notification_events, [:recipient_user_id, :event_type, :occurred_at], name: "index_notification_events_on_recipient_event_time"
    add_index :notification_events, :assignment_id

    add_foreign_key :notification_events, :users, column: :recipient_user_id
    add_foreign_key :notification_events, :users, column: :actor_user_id
    add_foreign_key :notification_events, :groups
    add_foreign_key :notification_events, :tasks
    add_foreign_key :notification_events, :assignments
  end
end
