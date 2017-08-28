# frozen_string_literal: true

load './lib/common.rb'

PAYLOAD = {
  key: 'DP',
  name: 'Kiffin\'s Dummy Project',
  projectTypeKey: 'software',
  description: 'Description of Kiffin\'s Dummy Project',
  lead: 'kiffin.gish'
}

def get_project_by_name(project_name)
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_PROJECT, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    result = body.find{|h| h['name'] == project_name}
    if result
      result.delete_if { |k,v| k =~ /expand|self|avatarurls/i} if result
      puts "GET #{URL_JIRA_PROJECT} => OK (already exists)"
    end
  rescue => e
    puts "GET #{URL_JIRA_PROJECT} => NOK (#{e.message})"
  end
  result
end

def create_project_by_payload(payload)
  project = get_project_by_name(payload[:name])
  return project if project
  begin
    RestClient::Request.execute(method: :post, url: URL_JIRA_PROJECT, payload: payload, headers: JIRA_HEADERS)
    puts "POST #{URL_JIRA_PROJECT} project='#{payload[:name]}' => OK"
  rescue => e
    puts "POST #{URL_JIRA_PROJECT} project='#{payload[:name]}' => NOK (#{e.message})"
  end
end

project = create_project_by_payload(PAYLOAD)

puts project.inspect

