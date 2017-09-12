# frozen_string_literal: true

load './lib/common.rb'

required_issuelink_types = [
  # JIRA
  {
    name: 'Blocks',
    inward: 'is blocked by',
    outward: 'blocks'
  },
  {
    name: 'Duplicate',
    inward: 'is duplicated by',
    outward: 'duplicates'
  },
  {
    name: 'Relates',
    inward: 'relates to',
    outward: 'relates to'
  },
  # ASSEMBLA
  {
    name: 'Parent',
    inward: 'is parent of',
    outward: 'is child of'
  },
  {
    name: 'Child',
    inward: 'is child of',
    outward: 'is parent of'
  },
  {
    name: 'Sibling',
    inward: 'is sibling of',
    outward: 'is sibling of'
  },
  {
    name: 'Story',
    inward: 'is story with subtask',
    outward: 'is subtask of story'
  },
  {
    name: 'Subtask',
    inward: 'is subtask of story',
    outward: 'is story with subtask'
  },
  {
    name: 'Dependent',
    inward: 'depends on',
    outward: 'depended on by'
  }
]

# Mapped:
# 'Related' => 'Relates' (replace 'd' with 's')
# 'Duplicate' => 'Duplicate' (exact match)
# 'Block' => 'Blocks' (append 's')

# POST /rest/api/2/issueLinkType
def jira_create_issuelink_type(issuelink_type)
  result = nil
  name = issuelink_type[:name]
  inward = issuelink_type[:inward]
  outward = issuelink_type[:outward]
  payload = {
    name: name,
    inward: inward,
    outward: outward
  }.to_json
  url = URL_JIRA_ISSUELINK_TYPES
  begin
    result = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    puts "POST #{url} '#{name}' => OK"
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} '#{name}' => NOK (#{e.message})"
  end
  result
end

actual_issuelink_types = jira_get_issuelink_types
required_issuelink_types.each do |required_issuelink_type|
  name = required_issuelink_type[:name]
  unless actual_issuelink_types.detect { |issuelink_type| issuelink_type['name'] == name }
    jira_create_issuelink_type(required_issuelink_type)
  end
end

FileUtils.mkdir_p(OUTPUT_DIR_JIRA) unless File.directory?(OUTPUT_DIR_JIRA)
write_csv_file("#{OUTPUT_DIR_JIRA}/jira-issuelink-types.csv", jira_get_issuelink_types)
