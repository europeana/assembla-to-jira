# frozen_string_literal: true

load './lib/common.rb'

FileUtils.mkdir_p(OUTPUT_DIR_JIRA) unless File.directory?(OUTPUT_DIR_JIRA)
write_csv_file("#{OUTPUT_DIR_JIRA}/jira-issuelink-types.csv", jira_get_issuelink_types)
