# frozen_string_literal: true

load './lib/common.rb'

# Iterate through all of the project names, and if a project does not already exist try and create it.
ASSEMBLA_SPACES.each do |name|
  project_name = name + (@debug ? ' TEST' : '')
  project = jira_get_project_by_name(project_name)
  jira_create_project(project_name) unless project
end
