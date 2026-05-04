class GenerateRecurringTasksJob < ActiveJob::Base
  queue_as :default
  BIWEEKLY_INTERVAL_DAYS = 14

  # target_dateを指定すると過去日/将来日の再生成確認にも使える
  def perform(target_date = nil)
    date = (target_date.present? ? Date.parse(target_date.to_s) : Time.zone.today)

    RecurringTask.where(active: true).find_each do |recurring_task|
      next unless due_on_date?(recurring_task, date)

      begin
        Task.create!(build_task_attributes(recurring_task, date))
      rescue ActiveRecord::RecordNotUnique
        # 二重生成防止ユニーク制約に引っかかった場合はスキップ
        next
      end
    end
  end

  private

  # 定期タスクが指定日に該当するかどうかを判定
  def due_on_date?(recurring_task, date)
    return false if date < recurring_task.starts_on
    return false unless recurring_task.day_of_week == date.wday

    return true if recurring_task.schedule_type == "weekly"
    return false unless recurring_task.schedule_type == "biweekly"

    first_date = recurring_task.starts_on + ((recurring_task.day_of_week - recurring_task.starts_on.wday) % 7)
    ((date - first_date).to_i % BIWEEKLY_INTERVAL_DAYS).zero?
  end

  # 定期タスクと生成予定日からタスクを作成
  def build_task_attributes(recurring_task, date)
    {
      group_id: recurring_task.group_id,
      name: recurring_task.name,
      description: recurring_task.description,
      point: recurring_task.point,
      source_recurring_task_id: recurring_task.id,
      scheduled_for: date,
      auto_generated: true
    }
  end
end
