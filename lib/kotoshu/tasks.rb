# frozen_string_literal: true

require "rake"
require "kotoshu/tasks/check_task"

# Wiring for `require "kotoshu/tasks"` (plan 89): installs the
# default `rake kotoshu:check` over the repository text files using
# the plan-88 file selection. Configure or add more tasks with
# Kotoshu::Tasks::CheckTask.new.
Kotoshu::Tasks::CheckTask.new
