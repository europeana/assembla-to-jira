# frozen_string_literal: true

load './lib/common.rb'

project_name = ASSEMBLA_SPACE + (@debug ? ' TEST' : '')
project = jira_get_project_by_name(project_name)
jira_create_project(project_name, JIRA_API_PROJECT_TYPE) unless project
