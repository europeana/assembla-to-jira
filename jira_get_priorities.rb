# frozen_string_literal: true

load './lib/common.rb'

FileUtils.mkdir_p(dirname) unless File.directory?(OUTPUT_DIR_JIRA)
write_csv_file("#{OUTPUT_DIR_JIRA}/jira-priorities.csv", jira_get_priorities)
