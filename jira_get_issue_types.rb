# frozen_string_literal: true

load './lib/common.rb'

def jira_get_issue_types(log)
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_ISSUE_TYPES, headers: JIRA_HEADERS)
    result = JSON.parse(response)
    if result
      result.each do |r|
        r.delete_if {|k,v| k.to_s =~ /self|iconurl|avatarid/i}
      end
      puts "GET #{URL_JIRA_ISSUE_TYPES} => OK (#{result.length})" if log
    end
  rescue => e
    puts "GET #{URL_JIRA_ISSUE_TYPES} => NOK (#{e.message})" if log
  end
  result
end

def jira_get_issue_type_id(type)
  issues = jira_get_issue_types(false)
  issue = issues.find { |issue| issue['name'].downcase == type.downcase }
  issue ? issue['id'] : 'unknown'
end

%w{task bug sub-task epic story}.each do |type|
  id = jira_get_issue_type_id(type)
  puts "#{type} => #{id}"
end

issues = jira_get_issue_types(true)

dirname = "#{OUTPUT_DIR}/jira"
FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
write_csv_file("#{dirname}/jira-issue-types.csv", issues)
